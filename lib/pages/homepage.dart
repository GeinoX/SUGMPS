import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sugmps/Attendance/Studattpage.dart';
import 'package:sugmps/core/routes/routes.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sugmps/core/adapters/course_adapter.dart';
import 'package:sugmps/services/course_service.dart';
import 'package:sugmps/Attendance/attpage2.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  File? profileImage;
  final ImagePicker picker = ImagePicker();
  final String baseUrl = AppRoutes.url;
  late final CourseService _service;
  late final Box<Course> _box;
  bool _isSyncing = false;
  bool _isInitialized = false;

  String? name;
  String? program;
  String? profileImagePath;

  // New state variables for semester and enrollment
  Map<String, dynamic>? currentSemester;
  List<dynamic> enrolledCourses = [];
  bool isLoadingSemester = true;
  bool isLoadingEnrolledCourses = false;
  bool _isLoggingOut = false;

  // Keys for local storage
  static const String _currentSemesterKey = 'current_semester';
  static const String _enrolledCoursesKey = 'enrolled_courses';

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _initHive();
    _loadLocalData(); // Load local data first
    _checkCurrentSemester(); // Then check with server
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CourseAdapter());
    }
    _box = await Hive.openBox<Course>('courses');
    _service = CourseService(baseUrl: baseUrl);

    setState(() {
      _isInitialized = true;
    });

    _sync(); // Initial sync
  }

  // Load data from local storage
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? semesterJson = prefs.getString(_currentSemesterKey);
    if (semesterJson != null) {
      setState(() {
        currentSemester = jsonDecode(semesterJson);
      });
    }

    final String? coursesJson = prefs.getString(_enrolledCoursesKey);
    if (coursesJson != null) {
      setState(() {
        enrolledCourses = jsonDecode(coursesJson);
      });
    }
  }

  // Save data to local storage
  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    if (currentSemester != null) {
      prefs.setString(_currentSemesterKey, jsonEncode(currentSemester));
    }

    prefs.setString(_enrolledCoursesKey, jsonEncode(enrolledCourses));
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _checkCurrentSemester() async {
    setState(() {
      isLoadingSemester = true;
    });

    final accessToken = await _getAccessToken();

    try {
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/currentsemester/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentSemester = data;
        });

        // Save to local storage
        await _saveLocalData();

        // If we have a current semester, check for enrolled courses
        if (data['status'] == 'Current') {
          await _checkEnrolledCourses(data['period'], data['year']);
        }
      } else {
        // No current semester or error
        setState(() {
          currentSemester = null;
        });
        if (response.statusCode == 401) {
          _showError('Please log in again');
        }
      }
    } catch (e) {
      print("Error checking current semester: $e");
      setState(() {
        currentSemester = null;
      });
    } finally {
      setState(() {
        isLoadingSemester = false;
      });
    }
  }

  Future<void> _checkEnrolledCourses(String period, int year) async {
    setState(() {
      isLoadingEnrolledCourses = true;
    });

    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showError('Please log in first');
      setState(() {
        isLoadingEnrolledCourses = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        '${AppRoutes.url}/umsapp/enrollfilter?period=$period&year=$year',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          enrolledCourses = data is List ? data : [];
        });

        // Save to local storage
        await _saveLocalData();
      } else if (response.statusCode == 401) {
        _showError('Please log in again');
      } else {
        _showError('Failed to load enrolled courses');
      }
    } catch (e) {
      print("Error checking enrolled courses: $e");
      // Maintain existing enrolled courses from local storage
    } finally {
      setState(() {
        isLoadingEnrolledCourses = false;
      });
    }
  }

  // Logout function
  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showError('No access token found');
      setState(() {
        _isLoggingOut = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppRoutes.url}/umsapp/logout/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        // Clear local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        await prefs.remove('student_name');
        await prefs.remove('student_program');
        await prefs.remove('student_image');
        await prefs.remove(_currentSemesterKey);
        await prefs.remove(_enrolledCoursesKey);

        // Navigate to login page
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } else if (response.statusCode == 403) {
        final responseData = jsonDecode(response.body);
        final message =
            responseData['message'] ?? 'You cannot logout at this time';
        _showError(message);
      } else {
        _showError('Logout failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Logout error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // Refresh function for pull-to-refresh
  Future<void> _refreshData() async {
    setState(() {
      isLoadingSemester = true;
      isLoadingEnrolledCourses = true;
    });

    await _checkCurrentSemester();
    if (currentSemester != null) {
      await _checkEnrolledCourses(
        currentSemester!['period'],
        currentSemester!['year'],
      );
    }
    await _sync();
  }

  void _showEnrollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => EnrollModal(
            currentSemester: currentSemester!,
            onEnrollSuccess: () {
              _checkEnrolledCourses(
                currentSemester!['period'],
                currentSemester!['year'],
              );
            },
          ),
    );
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    try {
      await _service.fetchAndSync(_box);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Synced with server')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Sync failed: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _openAttendancePage(String courseId, String courseName) async {
    if (mounted) {
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
  }

  Future<void> _deleteCourse(dynamic key) async {
    await _box.delete(key);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('🗑️ Deleted locally')));
    }
  }

  Future<void> _loadStudentInfo() async {
    final accessToken = await _getAccessToken();

    // Load locally first
    final prefs = await SharedPreferences.getInstance();
    String? localName = prefs.getString('student_name');
    String? localProgram = prefs.getString('student_program');
    String? localImage = prefs.getString('student_image');

    setState(() {
      name = localName ?? name;
      program = localProgram ?? program;
      profileImagePath = localImage ?? profileImagePath;
    });

    // Fetch from backend
    try {
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/stud_info/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        String? imageUrl = data['image']?.toString().trim();

        setState(() {
          name = data['name'];
          program = data['program'];
          profileImagePath = imageUrl;
        });

        prefs.setString('student_name', name!);
        prefs.setString('student_program', program!);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          prefs.setString('student_image', imageUrl);
        }
      } else {
        print('Failed to fetch student info. Status: ${response.statusCode}');
        if (response.statusCode == 401) {
          _showError('Please log in again to load student info');
        }
      }
    } catch (e) {
      print("Error fetching student info: $e");
      _showError('Failed to load student information');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCoursesSection() {
    if (isLoadingSemester) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading semester information...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (currentSemester == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No current semester',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check back later for updates',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final semesterName =
        '${currentSemester!['period']} ${currentSemester!['year']}';

    if (isLoadingEnrolledCourses) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
        ),
      );
    }

    return Column(
      children: [
        // Semester header with enroll button
        Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      semesterName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C3889),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      enrolledCourses.isEmpty
                          ? 'No courses enrolled'
                          : '${enrolledCourses.length} ${enrolledCourses.length == 1 ? 'course' : 'courses'} enrolled',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: _showEnrollModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3C3889),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Enroll',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        if (enrolledCourses.isEmpty)
          Container(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No courses enrolled for this semester',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the Enroll button to add courses',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: enrolledCourses.length,
            itemBuilder: (context, index) {
              final course = enrolledCourses[index];
              final color =
                  index % 2 == 0 ? Color(0xFF3C3889) : Color(0xFFE77B22);

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CourseCard(
                  color: color,
                  courseName: course['course_name'] ?? 'Unknown Course',
                  courseId: course['course_id'] ?? 'Unknown ID',
                  credits: course['credits'] ?? 0,
                  status: course['status'] ?? 'Unknown',
                  level: course['level'] ?? 'Unknown',
                  onOpen: () {
                    _openAttendancePage(
                      course['course_id'] ?? '',
                      course['course_name'] ?? 'Unknown Course',
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: screenWidth * 0.045,
          ),
        ),
        backgroundColor: Color(0xFF3C3889),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          _isLoggingOut
              ? Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
              : IconButton(
                icon: Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            children: [
              // Profile Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.04),
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
                      ClipOval(
                        child:
                            profileImagePath != null
                                ? CachedNetworkImage(
                                  imageUrl: profileImagePath!.trim(),
                                  width: screenWidth * 0.15,
                                  height: screenWidth * 0.15,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        width: screenWidth * 0.15,
                                        height: screenWidth * 0.15,
                                        color: Colors.grey.shade300,
                                        child: Icon(
                                          Icons.person,
                                          size: screenWidth * 0.06,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        width: screenWidth * 0.15,
                                        height: screenWidth * 0.15,
                                        color: Colors.grey.shade300,
                                        child: Icon(
                                          Icons.person,
                                          size: screenWidth * 0.06,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                )
                                : Container(
                                  width: screenWidth * 0.15,
                                  height: screenWidth * 0.15,
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.person,
                                    size: screenWidth * 0.06,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name ?? 'Loading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              program ?? 'Loading...',
                              style: TextStyle(
                                color: Color(0xFFE77B22),
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // Courses Section
              _buildCoursesSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// Responsive Course Card Widget
class CourseCard extends StatelessWidget {
  final Color color;
  final String courseName;
  final String courseId;
  final int credits;
  final String status;
  final String level;
  final VoidCallback onOpen;

  const CourseCard({
    super.key,
    required this.color,
    required this.courseName,
    required this.courseId,
    required this.credits,
    required this.status,
    required this.level,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.03,
          ),
          leading: Container(
            width: screenWidth * 0.1,
            height: screenWidth * 0.1,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              color: color,
              size: screenWidth * 0.05,
            ),
          ),
          title: Text(
            courseName,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                courseId,
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '$credits credits • ${status.toLowerCase()}',
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text(
              'Open',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Enrollment Modal widget
class EnrollModal extends StatelessWidget {
  final Map<String, dynamic> currentSemester;
  final VoidCallback onEnrollSuccess;

  const EnrollModal({
    Key? key,
    required this.currentSemester,
    required this.onEnrollSuccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enrollment Modal'),
          // Add your enrollment form widgets here
          ElevatedButton(
            onPressed: () {
              // Add enrollment logic here
              onEnrollSuccess();
              Navigator.pop(context);
            },
            child: Text('Enroll'),
          ),
        ],
      ),
    );
  }
}
