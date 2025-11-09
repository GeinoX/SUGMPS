// attendance_ble_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sugmps/core/routes/routes.dart';

const Color primaryBlue = Color(0xFF1565C0);
const Color accentOrange = Color(0xFFFFA726);
const String baseUrl = AppRoutes.url;
const int RSSI_STRONG_THRESHOLD = -70;

// Custom BLE identification constants
const String APP_BLE_PREFIX = "SUGMPS"; // 6-byte prefix for our app
const int APP_MANUFACTURER_ID = 0x1234; // Custom manufacturer ID
const int BLE_DATA_VERSION = 0x01; // Version byte

class AttendanceBlePage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String token;

  const AttendanceBlePage({
    Key? key,
    required this.courseId,
    required this.courseName,
    required this.token,
  }) : super(key: key);

  @override
  State<AttendanceBlePage> createState() => _AttendanceBlePageState();
}

class _AttendanceBlePageState extends State<AttendanceBlePage> {
  bool _scanning = false;
  bool _ischeckedin = false;
  String? _statusMessage;
  final List<_DetectedSession> _detected = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _scanTimer;

  // BLE peripheral for broadcasting
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  bool _broadcasting = false;
  String? _broadcastingSessionId;

  // Friend addition feature
  final List<TextEditingController> _friendControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<FocusNode> _friendFocusNodes = [FocusNode(), FocusNode()];

  late Box<Map> _localBox;

  @override
  void initState() {
    super.initState();
    _initHiveAndLoad();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan();
    _stopBroadcast();
    for (var controller in _friendControllers) {
      controller.dispose();
    }
    for (var focusNode in _friendFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _initHiveAndLoad() async {
    await Hive.initFlutter();
    _localBox = await Hive.openBox<Map>('offline_sessions');
    _loadLocalSessionsForCourse();
    setState(() => _statusMessage = 'Ready to scan');
  }

  void _loadLocalSessionsForCourse() {
    _detected.clear();
    for (final entry in _localBox.values) {
      try {
        final courseId = entry['courseId'] as String? ?? '';
        if (courseId != widget.courseId) continue;
        _detected.add(
          _DetectedSession(
            sessionId: entry['sessionId'] as String,
            rssi: entry['rssi'] as int? ?? -90,
            lastSeen:
                DateTime.tryParse(entry['lastSeen'] as String? ?? '') ??
                DateTime.now(),
            submitted: entry['submitted'] as bool? ?? false,
          ),
        );
      } catch (_) {}
    }
    _detected.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    setState(() {});
  }

  Future<void> _saveLocally(_DetectedSession ds) async {
    await _localBox.put(ds.sessionId, {
      'sessionId': ds.sessionId,
      'courseId': widget.courseId,
      'rssi': ds.rssi,
      'lastSeen': ds.lastSeen.toIso8601String(),
      'submitted': ds.submitted,
    });
  }

  Future<void> _markSubmittedLocally(String sessionId) async {
    final data = _localBox.get(sessionId);
    if (data == null) return;
    data['submitted'] = true;
    await _localBox.put(sessionId, data);
  }

  Future<void> _removeLocal(String sessionId) async {
    await _localBox.delete(sessionId);
  }

  // ========== BLE METHODS ==========

  /// Creates custom manufacturer data for our app sessions
  Uint8List _createManufacturerData(String sessionId) {
    final prefixBytes = utf8.encode(APP_BLE_PREFIX);
    final sessionBytes = utf8.encode(sessionId);

    final data = Uint8List(1 + prefixBytes.length + sessionBytes.length);
    data[0] = BLE_DATA_VERSION;
    data.setRange(1, 1 + prefixBytes.length, prefixBytes);
    data.setRange(1 + prefixBytes.length, data.length, sessionBytes);

    return data;
  }

  /// Extracts session ID from manufacturer data if it matches our app format
  String? _extractSessionIdFromManufacturerData(Uint8List data) {
    try {
      if (data.length < 7) return null;

      final version = data[0];
      if (version != BLE_DATA_VERSION) return null;

      final prefix = String.fromCharCodes(data.sublist(1, 7));
      if (prefix != APP_BLE_PREFIX) return null;

      final sessionIdBytes = data.sublist(7);
      return String.fromCharCodes(sessionIdBytes);
    } catch (_) {
      return null;
    }
  }

  /// Simple hex conversion utility
  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Creates a custom service UUID that encodes our app prefix
  String _createCustomServiceUuid(String sessionId) {
    // Convert prefix to hex for UUID inclusion
    final prefixBytes = utf8.encode(APP_BLE_PREFIX.substring(0, 4));
    final prefixHex = _bytesToHex(prefixBytes).padRight(8, '0').substring(0, 8);

    // Create simple hash from session ID for UUID
    final sessionHash = sessionId.hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');

    return '12345678-1234-5678-$prefixHex-$sessionHash';
  }

  /// Checks if a service UUID matches our app format
  String? _extractSessionIdFromServiceUuid(String serviceUuid) {
    try {
      // For simplicity, we'll use a different approach
      // Since we can't perfectly encode/decode session IDs in UUIDs,
      // we'll just verify it's our format and return a placeholder
      final parts = serviceUuid.split('-');
      if (parts.length == 5) {
        final prefixPart = parts[3];
        final sessionPart = parts[4];

        // Verify the prefix matches our expected format
        final expectedPrefix = _bytesToHex(
          utf8.encode(APP_BLE_PREFIX.substring(0, 4)),
        ).padRight(8, '0').substring(0, 8);

        if (prefixPart == expectedPrefix) {
          // For service UUIDs, we can't recover the full session ID,
          // so we'll create a unique identifier based on the UUID
          return "uuid-$serviceUuid";
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _statusMessage = 'Scanning for SUGMPS sessions...';
      _detected.clear();
    });

    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        String? sessionId;

        // ========== Check manufacturer data first ==========
        final manu = r.advertisementData.manufacturerData;
        if (manu.containsKey(APP_MANUFACTURER_ID)) {
          final bytes = manu[APP_MANUFACTURER_ID];
          if (bytes != null && bytes.isNotEmpty) {
            sessionId = _extractSessionIdFromManufacturerData(
              Uint8List.fromList(bytes),
            );
          }
        }

        // ========== Fallback to service UUIDs with our format ==========
        if (sessionId == null && r.advertisementData.serviceUuids.isNotEmpty) {
          for (final su in r.advertisementData.serviceUuids) {
            final suStr = su.toString();
            sessionId = _extractSessionIdFromServiceUuid(suStr);
            if (sessionId != null) break;
          }
        }

        // ========== Only process valid SUGMPS sessions ==========
        if (sessionId == null) continue;

        // Update existing session or add new
        final existingIdx = _detected.indexWhere(
          (d) => d.sessionId == sessionId,
        );
        if (existingIdx >= 0) {
          final updated = _detected[existingIdx].copyWith(
            rssi: r.rssi,
            lastSeen: DateTime.now(),
          );
          _detected[existingIdx] = updated;
          _saveLocally(updated);
        } else {
          final newSession = _DetectedSession(
            sessionId: sessionId!,
            rssi: r.rssi,
            lastSeen: DateTime.now(),
            submitted:
                (_localBox.get(sessionId)?['submitted'] as bool?) ?? false,
          );
          _detected.insert(0, newSession);
          _saveLocally(newSession);
        }

        setState(() {});
      }
    });

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 9), _stopScanNow);
  }

  void _stopScanNow() async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanTimer?.cancel();
    setState(() {
      _scanning = false;
      _statusMessage =
          'Scan complete. ${_detected.length} SUGMPS sessions found';
    });
  }

  // -------------------- SUBMIT (check-in) with Friends --------------------
  Future<void> _submitCheckIn(
    String sessionId,
    List<String> addedStudents,
  ) async {
    final uri = Uri.parse('$baseUrl/umsapp/attendance/check_in/');
    final payload = {
      "session_id": sessionId,
      "course_id": widget.courseId,
      "added_students": addedStudents,
    };

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await _markSubmittedLocally(sessionId);
        _ischeckedin = true;

        final idx = _detected.indexWhere((d) => d.sessionId == sessionId);
        if (idx >= 0) {
          _detected[idx] = _detected[idx].copyWith(submitted: true);
        }

        setState(() {
          _broadcastingSessionId = sessionId;
        });

        _clearFriendInputs();

        _showSnack(
          'Attendance submitted successfully! ${addedStudents.isNotEmpty ? 'Added students: ${addedStudents.join(", ")}' : ''}',
        );
      } else {
        _showSnack('Server rejected submission (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Network error: $e');
    }
  }

  // -------------------- FRIEND INPUT DIALOG --------------------
  Future<List<String>?> _showFriendInputDialog(String sessionId) async {
    _clearFriendInputs();

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Attendance'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session: ${_short(sessionId)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add up to 2 students (optional):',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _friendControllers[0],
                      focusNode: _friendFocusNodes[0],
                      decoration: const InputDecoration(
                        labelText: 'Student 1 ID',
                        border: OutlineInputBorder(),
                        hintText: 'Enter student ID (e.g., STU002)',
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _friendControllers[1],
                      focusNode: _friendFocusNodes[1],
                      decoration: const InputDecoration(
                        labelText: 'Student 2 ID',
                        border: OutlineInputBorder(),
                        hintText: 'Enter student ID (e.g., STU003)',
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_hasValidStudentInputs())
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Students to add: ${_getValidStudentIds().join(", ")}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: You can submit attendance without adding any students.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      _hasValidStudentInputs() || _allStudentInputsEmpty()
                          ? () {
                            final studentIds = _getValidStudentIds();
                            Navigator.of(context).pop(studentIds);
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                  ),
                  child: const Text('Submit Attendance'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _hasValidStudentInputs() {
    return _friendControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
  }

  bool _allStudentInputsEmpty() {
    return _friendControllers.every(
      (controller) => controller.text.trim().isEmpty,
    );
  }

  List<String> _getValidStudentIds() {
    return _friendControllers
        .map((controller) => controller.text.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  void _clearFriendInputs() {
    for (var controller in _friendControllers) {
      controller.clear();
    }
  }

  // -------------------- TILE ACTIONS --------------------
  Future<void> _onSessionTap(_DetectedSession ds) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Submit attendance'),
                subtitle: const Text('Add up to 2 other students'),
                onTap: () => Navigator.pop(context, 'submit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete (remove locally)'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (choice == 'submit') {
      final studentIds = await _showFriendInputDialog(ds.sessionId);
      if (studentIds != null) {
        final confirm = await _showConfirmDialog(
          'Submit Attendance',
          'Submit attendance for session ${_short(ds.sessionId)}${studentIds.isNotEmpty ? ' with ${studentIds.length} additional student(s)' : ''}?',
        );
        if (confirm == true) {
          await _submitCheckIn(ds.sessionId, studentIds);
        }
      }
    } else if (choice == 'delete') {
      final confirm = await _showConfirmDialog(
        'Delete stored session',
        'This will permanently delete the stored session ${_short(ds.sessionId)} for this course. Continue?',
      );
      if (confirm == true) {
        await _removeLocal(ds.sessionId);
        _detected.removeWhere((d) => d.sessionId == ds.sessionId);
        setState(() {});
        _showSnack('Deleted locally');
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // ========== FIXED BROADCAST METHOD with correct AdvertiseMode ==========
  Future<void> _startBroadcasting(String sessionId) async {
    if (sessionId.isEmpty) return;

    try {
      // Create AdvertiseData with required parameters
      final advertiseData = AdvertiseData(
        serviceUuid: _createCustomServiceUuid(sessionId),
        manufacturerId: APP_MANUFACTURER_ID,
        manufacturerData: _createManufacturerData(sessionId),
      );

      // Try different AdvertiseMode values - use the one that exists
      final advertiseSettings = AdvertiseSettings(
        advertiseMode:
            AdvertiseMode.advertiseModeBalanced, // Try this common value
        connectable: false,
        timeout: 0, // 0 means no timeout
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      setState(() {
        _broadcasting = true;
        _broadcastingSessionId = sessionId;
      });

      _showSnack('Broadcasting SUGMPS session ${_short(sessionId)}');
    } catch (e) {
      _showSnack('Broadcast failed: $e');
      print('Broadcast error: $e');

      // If AdvertiseMode.advertiseModeBalanced doesn't work, try without settings
      try {
        final advertiseData = AdvertiseData(
          serviceUuid: _createCustomServiceUuid(sessionId),
          manufacturerId: APP_MANUFACTURER_ID,
          manufacturerData: _createManufacturerData(sessionId),
        );

        await _blePeripheral.start(
          advertiseData: advertiseData,
          // Don't provide advertiseSettings to use defaults
        );

        setState(() {
          _broadcasting = true;
          _broadcastingSessionId = sessionId;
        });

        _showSnack(
          'Broadcasting SUGMPS session ${_short(sessionId)} (with default settings)',
        );
      } catch (e2) {
        _showSnack('Broadcast failed completely: $e2');
      }
    }
  }

  Future<void> _stopBroadcast() async {
    try {
      await _blePeripheral.stop();
    } catch (_) {}
    setState(() {
      _broadcasting = false;
      _broadcastingSessionId = null;
    });
  }

  Future<void> _toggleBroadcast() async {
    if (_broadcasting) {
      await _stopBroadcast();
    } else {
      if (_broadcastingSessionId == null) {
        _showSnack('No submitted session to broadcast. Submit one first.');
        return;
      }
      await _startBroadcasting(_broadcastingSessionId!);
    }
  }

  // -------------------- UTIL --------------------
  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool _looksLikeUuid(String s) =>
      RegExp(r'^[0-9a-fA-F\-]{8,36}$').hasMatch(s.trim());
  String _short(String s) => s.length <= 8 ? s : s.substring(0, 8);

  Widget _buildDetectedTile(_DetectedSession ds) {
    final isBroadcasting =
        _broadcasting && _broadcastingSessionId == ds.sessionId;
    final subtitle =
        ds.submitted
            ? 'Submitted • RSSI: ${ds.rssi} dBm'
            : 'Scanned • RSSI: ${ds.rssi} dBm';

    Widget trailing;
    if (isBroadcasting) {
      trailing = const Icon(Icons.campaign, color: Colors.orange);
    } else if (ds.submitted) {
      trailing = const Icon(Icons.check_circle, color: Colors.green);
    } else {
      trailing = const Icon(Icons.radio_button_unchecked, color: Colors.blue);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('Session ${_short(ds.sessionId)}'),
        subtitle: Text('$subtitle\nLast seen: ${ds.lastSeen.toLocal()}'),
        isThreeLine: true,
        trailing: trailing,
        onTap: () => _onSessionTap(ds),
      ),
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final hasSubmitted = _detected.any((d) => d.submitted);
    final btnEnabled = _broadcastingSessionId != null || hasSubmitted;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.orange,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Opacity(
              opacity: btnEnabled ? 1.0 : 0.5,
              child: IconButton(
                icon: Icon(
                  _broadcasting ? Icons.stop_circle : Icons.campaign,
                  color: const Color.fromARGB(255, 3, 47, 82),
                ),
                onPressed: btnEnabled ? _toggleBroadcast : null,
                tooltip:
                    _broadcasting
                        ? 'Stop broadcasting'
                        : 'Broadcast last submitted session',
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(_statusMessage ?? ''),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _scanning ? Icons.stop : Icons.bluetooth_searching,
                    ),
                    label: Text(_scanning ? 'Stop scan' : 'Start scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                    ),
                    onPressed: _scanning ? _stopScanNow : _startScan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _detected.isEmpty
                      ? const Center(
                        child: Text('No SUGMPS sessions detected.'),
                      )
                      : RefreshIndicator(
                        onRefresh: () async => _loadLocalSessionsForCourse(),
                        child: ListView.builder(
                          itemCount: _detected.length,
                          itemBuilder:
                              (_, i) => _buildDetectedTile(_detected[i]),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedSession {
  final String sessionId;
  final int rssi;
  final DateTime lastSeen;
  final bool submitted;

  _DetectedSession({
    required this.sessionId,
    required this.rssi,
    DateTime? lastSeen,
    this.submitted = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  _DetectedSession copyWith({
    String? sessionId,
    int? rssi,
    DateTime? lastSeen,
    bool? submitted,
  }) {
    return _DetectedSession(
      sessionId: sessionId ?? this.sessionId,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      submitted: submitted ?? this.submitted,
    );
  }

  factory _DetectedSession.empty() => _DetectedSession(
    sessionId: '',
    rssi: -999,
    lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
    submitted: false,
  );
}
