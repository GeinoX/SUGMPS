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
  Map<String, dynamic>? _currentSemester;
  bool _noActiveSemester = false;
  bool _refreshing = false;

  // Keys for local storage
  static const String _timetableKey = 'timetable_data';
  static const String _lastUpdatedKey = 'timetable_last_updated';
  static const String _currentSemesterKey = 'current_semester';

  @override
  void initState() {
    super.initState();
    _loadCurrentSemesterAndTimetable();
  }

  // Load current semester from local storage
  Future<void> _loadCurrentSemester() async {
    final prefs = await SharedPreferences.getInstance();
    final String? semesterJson = prefs.getString(_currentSemesterKey);

    if (semesterJson != null) {
      try {
        final semesterData = jsonDecode(semesterJson);
        setState(() {
          _currentSemester = semesterData;
          _noActiveSemester = semesterData['status'] != 'Current';
        });
      } catch (e) {
        print('Error loading current semester: $e');
      }
    }
  }

  // Fetch current semester from server
  Future<void> _fetchCurrentSemester() async {
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Please log in to view timetable';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/currentsemester/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool isActiveSemester = data['status'] == 'Current';

        setState(() {
          _currentSemester = data;
          _noActiveSemester = !isActiveSemester;
        });

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(_currentSemesterKey, jsonEncode(data));

        // If no active semester, clear timetable
        if (!isActiveSemester) {
          setState(() {
            _timetable = [];
          });
        }
      } else if (response.statusCode == 404) {
        // No current semester found
        setState(() {
          _currentSemester = null;
          _noActiveSemester = true;
          _timetable = [];
        });

        // Clear local semester data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_currentSemesterKey);
      } else {
        print('Failed to fetch current semester: ${response.statusCode}');
        // Continue with local semester data if available
      }
    } catch (e) {
      print('Error fetching current semester: $e');
      // Continue with local semester data if available
    }
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
        });
      } catch (e) {
        print('Error loading local timetable: $e');
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

  // Check if semester has changed
  Future<bool> _hasSemesterChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final String? oldSemesterJson = prefs.getString(_currentSemesterKey);

    if (oldSemesterJson == null) return true;

    try {
      final oldSemester = jsonDecode(oldSemesterJson);
      final newSemester = _currentSemester;

      if (newSemester == null) return false;

      return oldSemester['period'] != newSemester['period'] ||
          oldSemester['year'] != newSemester['year'];
    } catch (e) {
      return true;
    }
  }

  // Main initialization method
  Future<void> _loadCurrentSemesterAndTimetable() async {
    // Load local data first
    await _loadCurrentSemester();
    await _loadLocalTimetable();

    // Then fetch current semester from server
    await _fetchCurrentSemester();

    // Always try to fetch timetable, even if no active semester
    // This ensures we get the latest data if semester becomes active
    await _fetchTimetable();
  }

  // -------------------- FETCH TIMETABLE --------------------
  Future<void> _fetchTimetable() async {
    // Don't fetch timetable if no current semester at all
    if (_currentSemester == null) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      return;
    }

    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = true;
        _errorMessage = 'Please log in to view timetable';
      });
      return;
    }

    // Check if we have recent data and network is optional
    final isStale = await _isDataStale();
    final semesterChanged = await _hasSemesterChanged();

    // Force refresh if semester changed or data is stale
    final shouldRefresh = semesterChanged || isStale || _timetable.isEmpty;

    if (!shouldRefresh && _timetable.isNotEmpty) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = false;
      });
      // Still fetch in background for updates
      _fetchTimetableFromServer(accessToken);
      return;
    }

    await _fetchTimetableFromServer(accessToken);
  }

  Future<void> _fetchTimetableFromServer(String accessToken) async {
    if (_currentSemester == null) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      return;
    }

    final period = _currentSemester!['period'];
    final year = _currentSemester!['year'];

    // Build URL with current semester parameters
    final url = Uri.parse(
      '${AppRoutes.url}/umsapp/timetable?period=$period&year=$year',
    );

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
          _refreshing = false;
          _error = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = true;
          _errorMessage = 'Session expired. Please log in again.';
        });
      } else if (response.statusCode == 404) {
        // No timetable found for current semester
        setState(() {
          _timetable = [];
          _loading = false;
          _refreshing = false;
          _error = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No timetable available for ${_currentSemester!['period']} ${_currentSemester!['year']}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // If we have local data, show it with a warning
        if (_timetable.isNotEmpty) {
          setState(() {
            _loading = false;
            _refreshing = false;
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
            _refreshing = false;
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
          _refreshing = false;
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
          _refreshing = false;
          _error = true;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // -------------------- REFRESH FUNCTION --------------------
  Future<void> _refreshTimetable() async {
    setState(() {
      _refreshing = true;
      _error = false;
    });

    // Always refresh current semester first
    await _fetchCurrentSemester();

    // Always try to fetch timetable, even if no active semester
    // This ensures we get updates if semester becomes active
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

  // Get semester display name
  String _getSemesterDisplayName() {
    if (_currentSemester == null) return 'No Active Semester';
    return '${_currentSemester!['period']} ${_currentSemester!['year']}';
  }

  // Get semester status
  String _getSemesterStatus() {
    if (_currentSemester == null) return 'Inactive';
    return _currentSemester!['status'] ?? 'Inactive';
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
          // Always show refresh button, even when no data
          IconButton(
            icon:
                _refreshing
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshing ? null : _refreshTimetable,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refreshTimetable, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // Show loading state (only for initial load, not refresh)
    if (_loading && !_refreshing) {
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

    // Show error state
    if (_error) {
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

    // Show no active semester state
    if (_noActiveSemester || _currentSemester == null) {
      return Column(
        children: [
          // Show semester header even if no active semester
          if (_currentSemester != null) _buildSemesterHeader(),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _currentSemester == null
                        ? 'No Semester Found'
                        : 'No Active Semester',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _currentSemester == null
                          ? 'Unable to find any semester information. Please check back later.'
                          : 'There is currently no active semester. Please check back later when a new semester begins.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _refreshTimetable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C3889),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Check for Updates',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_currentSemester != null)
                    TextButton(
                      onPressed: () {
                        _showSemesterInfoDialog();
                      },
                      child: Text(
                        'View Semester Info',
                        style: TextStyle(
                          color: Color(0xFF3C3889),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
      return Column(
        children: [
          // Semester Header
          _buildSemesterHeader(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes scheduled for ${_getSemesterDisplayName()}.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back later for updates.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refreshTimetable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C3889),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Semester Header
        _buildSemesterHeader(),

        // Timetable Content
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timetable Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weekly Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C3889),
                      ),
                    ),
                    Text(
                      '${_timetable.length} classes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Days and Courses
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterHeader() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3C3889), Color(0xFF5A54A5)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSemesterDisplayName(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentSemester != null
                        ? 'Status: ${_getSemesterStatus()}'
                        : 'Checking for updates...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_refreshing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSemesterInfoDialog() {
    if (_currentSemester == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Semester Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Period: ${_currentSemester!['period']}'),
                Text('Year: ${_currentSemester!['year']}'),
                Text('Status: ${_currentSemester!['status']}'),
                if (_currentSemester!['start_date'] != null)
                  Text('Start Date: ${_currentSemester!['start_date']}'),
                if (_currentSemester!['end_date'] != null)
                  Text('End Date: ${_currentSemester!['end_date']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
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
