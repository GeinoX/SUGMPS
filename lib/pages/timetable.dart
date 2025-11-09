import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sugmps/core/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  List<Map<String, dynamic>> _timetable = [];
  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';

  // Keys for local storage
  static const String _timetableKey = 'timetable_data';
  static const String _lastUpdatedKey = 'timetable_last_updated';

  @override
  void initState() {
    super.initState();
    _loadLocalTimetable(); // Load local data first
    _fetchTimetable(); // Then fetch from server
  }

  // Load timetable from local storage
  Future<void> _loadLocalTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final String? timetableJson = prefs.getString(_timetableKey);

    if (timetableJson != null) {
      try {
        final List<dynamic> data = jsonDecode(timetableJson);
        setState(() {
          _timetable = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } catch (e) {
        print('Error loading local timetable: $e');
        // Continue to fetch from server
      }
    }
  }

  // Save timetable to local storage
  Future<void> _saveTimetable(List<Map<String, dynamic>> timetable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timetableKey, jsonEncode(timetable));
    await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
  }

  // Get last update time
  Future<DateTime?> _getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastUpdated = prefs.getString(_lastUpdatedKey);
    if (lastUpdated != null) {
      return DateTime.parse(lastUpdated);
    }
    return null;
  }

  // Check if data is stale (older than 1 hour)
  Future<bool> _isDataStale() async {
    final lastUpdate = await _getLastUpdateTime();
    if (lastUpdate == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    return difference.inHours > 1; // Consider data stale after 1 hour
  }

  // -------------------- FETCH TIMETABLE --------------------
  Future<void> _fetchTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Please log in to view timetable';
      });
      return;
    }

    // Check if we have recent data and network is optional
    final isStale = await _isDataStale();
    if (!isStale && _timetable.isNotEmpty) {
      setState(() {
        _loading = false;
        _error = false;
      });
      // Still fetch in background for updates
      _fetchTimetableFromServer(accessToken);
      return;
    }

    await _fetchTimetableFromServer(accessToken);
  }

  Future<void> _fetchTimetableFromServer(String accessToken) async {
    final url = Uri.parse('${AppRoutes.url}/umsapp/timetable');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );

        // Sort by day and start_time
        data.sort((a, b) {
          int dayOrder(String day) {
            switch (day) {
              case "Mon":
                return 1;
              case "Tue":
                return 2;
              case "Wed":
                return 3;
              case "Thu":
                return 4;
              case "Fri":
                return 5;
              case "Sat":
                return 6;
              case "Sun":
                return 7;
              default:
                return 8;
            }
          }

          int cmp = dayOrder(
            a['day'].toString(),
          ).compareTo(dayOrder(b['day'].toString()));
          if (cmp != 0) return cmp;

          return a['start_time'].toString().compareTo(
            b['start_time'].toString(),
          );
        });

        // Save to local storage
        await _saveTimetable(data);

        setState(() {
          _timetable = data;
          _loading = false;
          _error = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMessage = 'Session expired. Please log in again.';
        });
      } else {
        // If we have local data, show it with a warning
        if (_timetable.isNotEmpty) {
          setState(() {
            _loading = false;
            _error = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Using cached timetable data. Server returned: ${response.statusCode}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _loading = false;
            _error = true;
            _errorMessage = 'Failed to load timetable. Please try again.';
          });
        }
        print('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      // If we have local data, show it with a warning
      if (_timetable.isNotEmpty) {
        setState(() {
          _loading = false;
          _error = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Using cached timetable data. Network unavailable.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _loading = false;
          _error = true;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  // -------------------- REFRESH FUNCTION --------------------
  Future<void> _refreshTimetable() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    await _fetchTimetable();
  }

  // Clear local timetable data
  Future<void> _clearLocalTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_timetableKey);
    await prefs.remove(_lastUpdatedKey);
    setState(() {
      _timetable = [];
    });
    await _refreshTimetable();
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Timetable',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3C3889),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_timetable.isNotEmpty && !_loading)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'clear_cache') {
                  _clearLocalTimetable();
                } else if (value == 'force_refresh') {
                  _refreshTimetable();
                }
              },
              itemBuilder:
                  (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'force_refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Force Refresh'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'clear_cache',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear Cache'),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refreshTimetable, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _timetable.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading timetable...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error && _timetable.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshTimetable,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C3889),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Group courses by day
    Map<String, List<Map<String, dynamic>>> coursesByDay = {};
    for (var course in _timetable) {
      final day = course['day'].toString();
      coursesByDay.putIfAbsent(day, () => []);
      coursesByDay[day]!.add(course);
    }

    // Define ordered days (Mon → Sun)
    final List<String> daysOfWeek = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    // Filter out days with no courses
    final validDays =
        daysOfWeek.where((day) => coursesByDay.containsKey(day)).toList();

    if (validDays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No classes scheduled for this week.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for updates.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Schedule',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C3889),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3C3889),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_timetable.length} classes this week',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...validDays.map((day) {
            final courses = coursesByDay[day]!;
            final dayColor = _getDayColor(day);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dayColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day[0], // First letter of day
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dayColor,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  day,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${courses.length} ${courses.length == 1 ? 'class' : 'classes'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                children:
                    courses.map((course) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // Time indicator
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: dayColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Course details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course['course_name'].toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${course['start_time'].toString()} - ${course['end_time'].toString()}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        course['hall'].toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'Mon':
        return Colors.blue;
      case 'Tue':
        return Colors.green;
      case 'Wed':
        return Colors.orange;
      case 'Thu':
        return Colors.purple;
      case 'Fri':
        return Colors.red;
      case 'Sat':
        return Colors.teal;
      case 'Sun':
        return Colors.pink;
      default:
        return const Color(0xFF3C3889);
    }
  }
}
