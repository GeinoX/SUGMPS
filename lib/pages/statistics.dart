import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/core/routes/routes.dart';
import 'package:sugmps/Attendance/Studattpage.dart'; // For StudentAttendancePage

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = false;
  bool _isLoadingSemester = true;
  String? _error;

  // Semester selection
  final _years = List.generate(
    6,
    (i) => (DateTime.now().year - 2 + i).toString(),
  );
  final _semesters = ['Spring', 'Summer', 'Fall', 'Autumn'];
  String? _selectedYear;
  String? _selectedSemester;

  Map<String, dynamic>? currentSemester;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _selectedYear = _years[2];
    _selectedSemester = _semesters[0];
    _loadTeacherDetails();
    _checkCurrentSemester();
  }

  Future<void> _loadTeacherDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('accessToken');
    });
  }

  Future<void> _checkCurrentSemester() async {
    setState(() {
      _isLoadingSemester = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/currentsemester/'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentSemester = data;
        });

        // Auto-select current semester if available
        if (data['status'] == 'Current') {
          setState(() {
            _selectedYear = data['year'].toString();
            _selectedSemester = data['period'];
          });
          await _fetchEnrolledCourses();
        }
      }
    } catch (e) {
      print("Error checking current semester: $e");
    } finally {
      setState(() {
        _isLoadingSemester = false;
      });
    }
  }

  Future<void> _fetchEnrolledCourses() async {
    if (_selectedYear == null || _selectedSemester == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        '${AppRoutes.url}/umsapp/enrollfilter?period=$_selectedSemester&year=$_selectedYear',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coursesData = data is List ? data : [];

        // Fetch statistics for each course
        final List<Map<String, dynamic>> coursesWithStats = [];

        for (var course in coursesData) {
          final stats = await _fetchCourseStatistics(course['course_id']);
          coursesWithStats.add({
            ...course,
            'attendance_percentage': stats['attendance_percentage'] ?? 0,
            'total_classes': stats['total_classes'] ?? 0,
            'attended_classes': stats['attended_classes'] ?? 0,
            'performance_grade': stats['performance_grade'] ?? 'N/A',
          });
        }

        setState(() {
          _courses = coursesWithStats;
        });
      } else {
        setState(() {
          _error = 'Failed to load courses';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchCourseStatistics(String courseId) async {
    try {
      // Using the same endpoint as homepage for attendance details
      final response = await http.get(
        Uri.parse(
          '${AppRoutes.url}/umsapp/course_attendance/?course_id=$courseId',
        ),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Calculate statistics from attendance data
        final List<dynamic> attendanceRecords = data is List ? data : [];
        final totalClasses = attendanceRecords.length;
        final attendedClasses =
            attendanceRecords
                .where((record) => record['status'] == 'Present')
                .length;
        final percentage =
            totalClasses > 0 ? (attendedClasses / totalClasses * 100) : 0;

        // Determine performance grade
        String performanceGrade = 'N/A';
        if (percentage >= 90)
          performanceGrade = 'A';
        else if (percentage >= 80)
          performanceGrade = 'B';
        else if (percentage >= 70)
          performanceGrade = 'C';
        else if (percentage >= 60)
          performanceGrade = 'D';
        else if (percentage > 0)
          performanceGrade = 'F';

        return {
          'attendance_percentage': percentage.round(),
          'total_classes': totalClasses,
          'attended_classes': attendedClasses,
          'performance_grade': performanceGrade,
        };
      }
    } catch (e) {
      print("Error fetching course statistics: $e");
    }

    return {
      'attendance_percentage': 0,
      'total_classes': 0,
      'attended_classes': 0,
      'performance_grade': 'N/A',
    };
  }

  void _openCourseStatistics(String courseId, String courseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => StudentAttendancePage(
              courseId: courseId,
              courseName: courseName,
            ),
      ),
    );
  }

  Widget _buildDropdowns() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedYear,
                decoration: _inputDecoration('Year'),
                items:
                    _years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                onChanged: (val) {
                  setState(() => _selectedYear = val);
                },
                isExpanded: true,
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedSemester,
                decoration: _inputDecoration('Semester'),
                items:
                    _semesters
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (val) {
                  setState(() => _selectedSemester = val);
                },
                isExpanded: true,
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> course, int index) {
    final color = index % 2 == 0 ? Color(0xFF3C3889) : Color(0xFFE77B22);
    final attendancePercentage = course['attendance_percentage'] ?? 0;
    final totalClasses = course['total_classes'] ?? 0;
    final attendedClasses = course['attended_classes'] ?? 0;
    final performanceGrade = course['performance_grade'] ?? 'N/A';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 350;
              final isVerySmallScreen = constraints.maxWidth < 300;

              return Column(
                children: [
                  // Course Header - Made more flexible
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isVerySmallScreen ? 40 : 50,
                        height: isVerySmallScreen ? 40 : 50,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: color,
                          size: isVerySmallScreen ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isVerySmallScreen ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['course_name'] ?? 'Unknown Course',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C3889),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              course['course_id'] ?? 'Unknown ID',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 12 : 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Statistics Grid - Made responsive
                  if (isVerySmallScreen) ...[
                    // Vertical layout for very small screens
                    _buildStatItem(
                      'Attendance',
                      '$attendancePercentage%',
                      Icons.calendar_today,
                      color,
                      isSmallScreen: isVerySmallScreen,
                    ),
                    SizedBox(height: 8),
                    _buildStatItem(
                      'Grade',
                      performanceGrade,
                      Icons.grade,
                      color,
                      isSmallScreen: isVerySmallScreen,
                    ),
                  ] else ...[
                    // Horizontal layout for normal screens
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Attendance',
                            '$attendancePercentage%',
                            Icons.calendar_today,
                            color,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Expanded(
                          child: _buildStatItem(
                            'Grade',
                            performanceGrade,
                            Icons.grade,
                            color,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 12),

                  // Attendance Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Attendance Progress',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '$attendedClasses/$totalClasses',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: attendancePercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(attendancePercentage),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 8,
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // View Details Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _openCourseStatistics(
                          course['course_id'],
                          course['course_name'],
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isVerySmallScreen ? 10 : 12,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'View Detailed Statistics',
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(int percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.amber;
    return Colors.red;
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;

        if (_isLoadingSemester) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Loading semester information...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        if (_loading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Loading course statistics...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        if (_error != null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: isSmallScreen ? 48 : 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchEnrolledCourses,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3C3889),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_courses.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: isSmallScreen ? 48 : 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No courses found',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Selected: ${_selectedYear ?? "-"} • ${_selectedSemester ?? "-"}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          itemCount: _courses.length,
          itemBuilder: (context, index) {
            return _buildStatisticsCard(_courses[index], index);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Course Statistics',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: Color(0xFF3C3889),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Semester Selection Card
            Card(
              elevation: 2,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDropdowns(),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _fetchEnrolledCourses,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3C3889),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _loading
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'Load Statistics',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Statistics List
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
