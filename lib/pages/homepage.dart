import 'package:flutter/material.dart';
import 'package:sugmps/core/routes/routes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sugmps/core/adapters/course_adapter.dart';
import 'package:sugmps/services/course_service.dart';
import 'package:sugmps/Attendance/Studattpage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class Homepage extends StatefulWidget {
  const Homepage({super.key});  

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final String baseUrl = AppRoutes.url;
  late final CourseService _service;
  late final Box<Course> _box;
  bool _isSyncing = false;
  bool _isInitialized = false;

  String? name;
  String? program;
  String? profileImageUrl;

  // New state variables for semester and enrollment
  Map<String, dynamic>? currentSemester;
  List<dynamic> enrolledCourses = [];
  bool isLoadingSemester = true;
  bool isLoadingEnrolledCourses = false;
  bool _isLoggingOut = false;

  // Add these for local image picking
  final ImagePicker _picker = ImagePicker();
  File? _localPickedImage;

  // Keys for local storage
  static const String _currentSemesterKey = 'current_semester';
  static const String _enrolledCoursesKey = 'enrolled_courses';
  static const String _userProfileKey = 'user_profile';

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _initHive();
    _loadLocalData();
    _checkCurrentSemester();
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

    _sync();
  }

  // SIMPLIFIED: Just pick and display image locally
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _localPickedImage = File(pickedFile.path);
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated locally'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Load data from local storage
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load semester data
    final String? semesterJson = prefs.getString(_currentSemesterKey);
    if (semesterJson != null) {
      setState(() {
        currentSemester = jsonDecode(semesterJson);
      });
    }

    // Load enrolled courses
    final String? coursesJson = prefs.getString(_enrolledCoursesKey);
    if (coursesJson != null) {
      setState(() {
        enrolledCourses = jsonDecode(coursesJson);
      });
    }

    // Load user profile data
    final String? userProfileJson = prefs.getString(_userProfileKey);
    if (userProfileJson != null) {
      final userData = jsonDecode(userProfileJson);
      setState(() {
        name = userData['name'];
        program = userData['program'];
        profileImageUrl = userData['profile_image_url'];
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

    // Save user profile data
    final userProfile = {
      'name': name,
      'program': program,
      'profile_image_url': profileImageUrl,
    };
    prefs.setString(_userProfileKey, jsonEncode(userProfile));
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

        await _saveLocalData();

        if (data['status'] == 'Current') {
          await _checkEnrolledCourses(data['period'], data['year']);
        }
      } else {
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

        await _saveLocalData();
      } else if (response.statusCode == 401) {
        _showError('Please log in again');
      } else {
        _showError('Failed to load enrolled courses');
      }
    } catch (e) {
      print("Error checking enrolled courses: $e");
    } finally {
      setState(() {
        isLoadingEnrolledCourses = false;
      });
    }
  }

  // Enhanced student info loading with profile image URL support
  Future<void> _loadStudentInfo() async {
    final accessToken = await _getAccessToken();

    // Load locally first
    final prefs = await SharedPreferences.getInstance();
    String? localName = prefs.getString('student_name');
    String? localProgram = prefs.getString('student_program');
    String? localImageUrl = prefs.getString('student_image_url');

    setState(() {
      name = localName ?? name;
      program = localProgram ?? program;
      profileImageUrl = localImageUrl ?? profileImageUrl;
    });

    // Fetch from backend
    try {
      final response = await http.get(   
        Uri.parse('${AppRoutes.url}/umsapp/stud_info/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats
        Map<String, dynamic> userData;
        if (data.containsKey('data')) {
          userData = data['data'];
        } else if (data.containsKey('user')) {
          userData = data['user'];
        } else {
          userData = data;
        }

        String? imageUrl =
            userData['profile_image_url'] ??
            userData['image']?.toString().trim();

        setState(() {
          name = userData['name'] ?? name;
          program = userData['program'] ?? program;
          profileImageUrl = imageUrl;
        });

        // Save to local storage with updated keys
        prefs.setString('student_name', name!);
        prefs.setString('student_program', program!);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          prefs.setString('student_image_url', imageUrl);
        }

        await _saveLocalData();
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

  // UPDATED: Simple profile image widget that shows local image when picked
  Widget _buildProfileImage() {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          // Show locally picked image if available, otherwise show network image or placeholder
          if (_localPickedImage != null)
            CircleAvatar(
              radius: screenWidth * 0.075,
              backgroundImage: FileImage(_localPickedImage!),
            )
          else if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: profileImageUrl!.trim(),
              width: screenWidth * 0.15,
              height: screenWidth * 0.15,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholderAvatar(screenWidth),
              errorWidget: (context, url, error) => _buildPlaceholderAvatar(screenWidth),
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: screenWidth * 0.075,
                backgroundImage: imageProvider,
              ),
            )
          else
            _buildPlaceholderAvatar(screenWidth),

          // Camera icon overlay to indicate it's clickable
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color(0xFF3C3889),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: screenWidth * 0.03,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(double screenWidth) {
    return CircleAvatar(
      radius: screenWidth * 0.075,
      backgroundColor: Colors.grey.shade300,
      child: Icon(
        Icons.person,
        size: screenWidth * 0.06,
        color: Colors.grey.shade600,
      ),
    );
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
        // Clear all local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        await prefs.remove('student_name');
        await prefs.remove('student_program');
        await prefs.remove('student_image');
        await prefs.remove('student_image_url');
        await prefs.remove(_currentSemesterKey);
        await prefs.remove(_enrolledCoursesKey);
        await prefs.remove(_userProfileKey);

        // Navigate to login page
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } else if (response.statusCode == 403) {
        final responseData = jsonDecode(response.body);
        final message = responseData['message'] ?? 'You cannot logout at this time';
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
    await _loadStudentInfo();
    await _sync();
  }

  void _showEnrollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EnrollModal(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Synced with server'))
        );
      }
    } catch (e) {
      print('Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Sync failed: $e'))
        );
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
          builder: (_) => StudentAttendancePage(
            courseId: courseId,
            courseName: courseName,
          ),
        ),
      );
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
    // Your existing _buildCoursesSection implementation remains exactly the same
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

    final semesterName = '${currentSemester!['period']} ${currentSemester!['year']}';

    if (isLoadingEnrolledCourses) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
        ),
      );
    }

    return Column(
      children: [
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
              final color = index % 2 == 0 ? Color(0xFF3C3889) : Color(0xFFE77B22);

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
                      // UPDATED: Profile Image with simple tap-to-pick functionality
                      _buildProfileImage(),
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

// Your existing CourseCard and EnrollModal classes remain exactly the same
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

// Your existing EnrollModal class remains exactly the same
class EnrollModal extends StatefulWidget {
  final Map<String, dynamic> currentSemester;
  final VoidCallback onEnrollSuccess;

  const EnrollModal({
    Key? key,
    required this.currentSemester,
    required this.onEnrollSuccess,
  }) : super(key: key);

  @override
  State<EnrollModal> createState() => _EnrollModalState();
}

class _EnrollModalState extends State<EnrollModal> {
  List<dynamic> availableCourses = [];
  List<dynamic> selectedCourses = [];
  bool isLoading = false;
  bool isEnrolling = false;
  String? errorMessage;
  String? selectedLevel;

  final List<String> levels = [
    'l1s1', 'l1s2', 'l2s1', 'l2s2', 'l3s1', 'l3s2', 'l4s1', 'l4s2',
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _loadCoursesForLevel(String level) async {
    setState(() {
      isLoading = true;
      selectedLevel = level;
      errorMessage = null;
      availableCourses = [];
      selectedCourses = [];
    });

    try {
      final accessToken = await _getAccessToken();
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/courses/$level'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          availableCourses = data is List ? data : [];
        });
      } else if (response.statusCode == 404) {
        setState(() {
          availableCourses = [];
          errorMessage = 'No courses found for $level';
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load courses for $level';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading courses: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _enrollSelectedCourses() async {
    if (selectedCourses.isEmpty) {
      setState(() {
        errorMessage = 'Please select at least one course';
      });
      return;
    }

    setState(() {
      isEnrolling = true;
      errorMessage = null;
    });

    try {
      final accessToken = await _getAccessToken();

      for (final course in selectedCourses) {
        final response = await http.post(
          Uri.parse('${AppRoutes.url}/umsapp/enroll'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'course_name': course['course_id'],
            'period': widget.currentSemester['period'],
            'year': widget.currentSemester['year'],
          }),
        );

        if (response.statusCode != 200) {
          final errorData = jsonDecode(response.body);
          throw Exception(
            errorData['message'] ?? 'Enrollment failed for ${course['course_name']}',
          );
        }
      }

      widget.onEnrollSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully enrolled in ${selectedCourses.length} course(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isEnrolling = false;
      });
    }
  }

  void _toggleCourseSelection(dynamic course) {
    setState(() {
      if (selectedCourses.any((c) => c['course_id'] == course['course_id'])) {
        selectedCourses.removeWhere((c) => c['course_id'] == course['course_id']);
      } else {
        selectedCourses.add(course);
      }
    });
  }

  bool _isCourseSelected(dynamic course) {
    return selectedCourses.any((c) => c['course_id'] == course['course_id']);
  }

  String _getLevelDisplayName(String level) {
    final Map<String, String> levelNames = {
      'l1s1': 'Level 1 Semester 1', 'l1s2': 'Level 1 Semester 2',
      'l2s1': 'Level 2 Semester 1', 'l2s2': 'Level 2 Semester 2',
      'l3s1': 'Level 3 Semester 1', 'l3s2': 'Level 3 Semester 2',
      'l4s1': 'Level 4 Semester 1', 'l4s2': 'Level 4 Semester 2',
    };
    return levelNames[level] ?? level;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 24, vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Color(0xFF3C3889),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course Enrollment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${widget.currentSemester['period']} ${widget.currentSemester['year']}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
          // ... rest of your existing EnrollModal build method remains exactly the same
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 24, vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Level',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: levels.map((level) {
                    final isSelected = selectedLevel == level;
                    return FilterChip(
                      selected: isSelected,
                      onSelected: (_) => _loadCoursesForLevel(level),
                      label: Text(
                        _getLevelDisplayName(level),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      selectedColor: Color(0xFF3C3889),
                      backgroundColor: Colors.grey[200],
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (selectedCourses.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 24, vertical: 12,
              ),
              color: Color(0xFF3C3889).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedCourses.length} course(s) selected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3889),
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  Text(
                    '${selectedCourses.fold<int>(0, (sum, course) => sum + (course['credits'] as int? ?? 0))} credits',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          if (errorMessage != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 24, vertical: 12,
              ),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: isSmallScreen ? 14 : 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (selectedLevel != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.4, minHeight: screenHeight * 0.2,
              ),
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C3889)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading courses for ${_getLevelDisplayName(selectedLevel!)}...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : availableCourses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_outlined, size: isSmallScreen ? 48 : 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'No courses available',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No courses found for ${_getLevelDisplayName(selectedLevel!)}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 15,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: isSmallScreen ? 16 : 20),
                          itemCount: availableCourses.length,
                          itemBuilder: (context, index) {
                            final course = availableCourses[index];
                            final isSelected = _isCourseSelected(course);
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? Color(0xFF3C3889) : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleCourseSelection(course),
                                  activeColor: Color(0xFF3C3889),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                title: Text(
                                  course['course_name'] ?? 'Unknown Course',
                                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text(
                                      course['course_id'] ?? 'Unknown ID',
                                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${course['credits'] ?? 0} credits',
                                          style: TextStyle(fontSize: isSmallScreen ? 12 : 13, color: Colors.grey[600]),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFE77B22).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            course['status'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 10 : 11,
                                              color: Color(0xFFE77B22),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _toggleCourseSelection(course),
                              ),
                            );
                          },
                        ),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 24, vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedCourses.isEmpty || isEnrolling) ? null : _enrollSelectedCourses,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3C3889),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    child: isEnrolling
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Enroll Selected',
                            style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}