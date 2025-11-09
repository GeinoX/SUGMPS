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
  String? _broadcastingSessionId; // which session we are broadcasting

  // Friend addition feature
  final List<TextEditingController> _friendControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<FocusNode> _friendFocusNodes = [FocusNode(), FocusNode()];

  late Box<Map> _localBox; // single box; entries include courseId

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
    // Dispose controllers and focus nodes
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
    _localBox = await Hive.openBox<Map>('offline_sessions'); // single box
    _loadLocalSessionsForCourse();
    setState(() => _statusMessage = 'Ready to scan');
  }

  void _loadLocalSessionsForCourse() {
    _detected.clear();
    for (final entry in _localBox.values) {
      try {
        final courseId = entry['courseId'] as String? ?? '';
        if (courseId != widget.courseId) continue; // only this course
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
      } catch (_) {
        // ignore malformed entries
      }
    }
    // keep newest-first (optional)
    _detected.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    setState(() {});
  }

  Future<void> _saveLocally(_DetectedSession ds) async {
    // store a map with courseId; overwrite if exists
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

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _statusMessage = 'Scanning for sessions...';
    });

    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        String? sessionId;

        // Check manufacturerData with specific manufacturerId
        const targetManufacturerId = 0xFFFF;
        final manu = r.advertisementData.manufacturerData;
        if (manu.containsKey(targetManufacturerId)) {
          final bytes = manu[targetManufacturerId];
          if (bytes != null) {
            try {
              final decoded = String.fromCharCodes(bytes);
              if (_looksLikeUuid(decoded)) {
                sessionId = decoded;
              }
            } catch (_) {}
          }
        }

        // Fall back to service UUIDs if no valid manufacturerData
        if (sessionId == null && r.advertisementData.serviceUuids.isNotEmpty) {
          for (final su in r.advertisementData.serviceUuids) {
            final suStr = su.str128;
            if (_looksLikeUuid(suStr)) {
              sessionId = suStr;
              break;
            }
          }
        }

        // ✅ Skip devices with sessionId starting with 0000
        if (sessionId == null || sessionId.startsWith('0000')) continue;

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
            sessionId: sessionId,
            rssi: r.rssi,
            lastSeen: DateTime.now(),
            submitted:
                (_localBox.get(sessionId)?['submitted'] as bool?) ?? false,
          );
          _detected.insert(0, newSession); // newest first
          _saveLocally(newSession);
        }

        setState(() {});
      }
    });

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 8),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 9), _stopScanNow);
  }

  void _stopScanNow() async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanTimer?.cancel();
    setState(() {
      _scanning = false;
      _statusMessage = 'Scan complete. ${_detected.length} found';
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
      "added_students": addedStudents, // Match your API field name
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
        // mark submitted locally (we keep the record so user can broadcast)
        await _markSubmittedLocally(sessionId);
        _ischeckedin = true;

        // update in-memory list
        final idx = _detected.indexWhere((d) => d.sessionId == sessionId);
        if (idx >= 0) {
          _detected[idx] = _detected[idx].copyWith(submitted: true);
        }

        // set last submitted session for broadcasting
        setState(() {
          _broadcastingSessionId = sessionId;
        });

        // Clear friend inputs after successful submission
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
    // Reset friend inputs
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
                    // Student 1 input
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
                    // Student 2 input
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
                    Navigator.of(context).pop(null); // Cancel
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
    // Show options: Submit, Delete, Cancel
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
    // else cancel — do nothing
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

  // -------------------- BROADCAST --------------------
  Future<void> _startBroadcasting(String sessionId) async {
    if (sessionId.isEmpty) return;

    try {
      final advertiseData = AdvertiseData(
        includeDeviceName: false, // optional
        serviceUuid: sessionId, // broadcast recognition ID
        manufacturerId: 0xFFFF, // fixed 16-bit manufacturer ID
        manufacturerData: Uint8List.fromList(
          utf8.encode(sessionId),
        ), // session info
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      setState(() {
        _broadcasting = true;
        _broadcastingSessionId = sessionId;
      });

      _showSnack('Broadcasting session ${_short(sessionId)}');
    } catch (e) {
      _showSnack('Broadcast failed: $e');
      print(e);
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

  // Toggle broadcast button behavior
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
    // prefer broadcastingSessionId if set; else pick last submitted
    final btnEnabled = _broadcastingSessionId != null || hasSubmitted;
    final effectiveBroadcastId =
        _broadcastingSessionId ??
        (_detected
            .firstWhere(
              (d) => d.submitted,
              orElse: () => _DetectedSession.empty(),
            )
            .sessionId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.orange,
        actions: [
          // Broadcast button
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
                        child: Text('No stored sessions for this course.'),
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

// -------------------- Data class --------------------
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

  // empty sentinel for broadcast selection
  factory _DetectedSession.empty() => _DetectedSession(
    sessionId: '',
    rssi: -999,
    lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
    submitted: false,
  );
}
