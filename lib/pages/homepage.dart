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
        if (response.statusCode == 401) {
          _showError('Please log in again');
        }
      }
    } catch (e) {
      print("Error checking current semester: $e");
      // Don't clear currentSemester here to maintain local data
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

  // Refresh function for pull-to-refresh
  Future<void> _refreshData() async {
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
    final token = await _getAccessToken();

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => StudentAttendancePage(
                // ✅ Correct page
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickimage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  Widget _buildCoursesSection() {
    if (isLoadingSemester) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentSemester == null) {
      return const Center(
        child: Text(
          'No current semester',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final semesterName =
        '${currentSemester!['period']} ${currentSemester!['year']}';

    if (isLoadingEnrolledCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    // Always show the semester title with enroll button
    return Column(
      children: [
        // Semester title row with enroll button on the right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(
              label: semesterName,
              screenWidth: MediaQuery.of(context).size.width,
            ),
            ElevatedButton(
              onPressed: _showEnrollModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C3889),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Enroll',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),

        if (enrolledCourses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            child: const Column(
              children: [
                Text(
                  'No courses enrolled for this semester',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          // Display enrolled courses
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: enrolledCourses.length,
            itemBuilder: (context, index) {
              final course = enrolledCourses[index];
              final color =
                  index % 2 == 0
                      ? const Color(0xFF3C3889)
                      : const Color(0xFFE77B22);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    child: CustomBox(
                      color: color,
                      courseName: course['course_name'] ?? 'Unknown Course',
                      courseId: course['course_id'] ?? 'Unknown ID',
                      credit: course['credits'] ?? 0,
                      status: course['status'] ?? 'Unknown',
                      level: course['level'] ?? 'Unknown',
                      onOpen: () {
                        _openAttendancePage(
                          course['course_id'] ?? '',
                          course['course_name'] ?? 'Unknown Course',
                        );
                      },
                      onDelete: () {
                        // Implement course drop functionality if needed
                      },
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
      ),
      backgroundColor: const Color.fromRGBO(255, 255, 255, 0.95),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(), // Required for RefreshIndicator
            child: Column(
              children: [
                // Profile Container
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  height: screenHeight * 0.12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3889),
                    borderRadius: BorderRadius.circular(screenWidth * 0.04),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Profile Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ClipOval(
                            child:
                                profileImagePath != null
                                    ? CachedNetworkImage(
                                      imageUrl: profileImagePath!.trim(),
                                      width: screenWidth * 0.16,
                                      height: screenWidth * 0.16,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            width: screenWidth * 0.16,
                                            height: screenWidth * 0.16,
                                            color: Colors.grey.shade300,
                                            child: Icon(
                                              Icons.person,
                                              size: screenWidth * 0.06,
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) => Container(
                                            width: screenWidth * 0.16,
                                            height: screenWidth * 0.16,
                                            color: Colors.grey.shade300,
                                            child: Icon(
                                              Icons.person,
                                              size: screenWidth * 0.06,
                                            ),
                                          ),
                                    )
                                    : Container(
                                      width: screenWidth * 0.16,
                                      height: screenWidth * 0.16,
                                      color: Colors.grey.shade300,
                                      child: Icon(
                                        Icons.person,
                                        size: screenWidth * 0.06,
                                      ),
                                    ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name ?? 'Loading...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.005),
                              Text(
                                program ?? 'Loading...',
                                style: TextStyle(
                                  color: const Color(0xFFE77B22),
                                  fontSize: screenWidth * 0.03,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Attendance Progress
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.03),
                _buildCoursesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enrollment Modal
class EnrollModal extends StatefulWidget {
  final Map<String, dynamic> currentSemester;
  final VoidCallback onEnrollSuccess;

  const EnrollModal({
    super.key,
    required this.currentSemester,
    required this.onEnrollSuccess,
  });

  @override
  _EnrollModalState createState() => _EnrollModalState();
}

class _EnrollModalState extends State<EnrollModal> {
  List<String> levels = [
    'l1s1',
    'l1s2',
    'l2s1',
    'l2s2',
    'l3s1',
    'l3s2',
    'l4s1',
    'l4s2',
  ]; // You can add more levels as needed
  Map<String, List<dynamic>> levelCourses = {};
  String? selectedLevel;
  bool isLoadingCourses = false;
  Set<String> selectedCourses = Set();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enroll in Courses - ${widget.currentSemester['period']} ${widget.currentSemester['year']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Level Selection
          const Text(
            'Select Level:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children:
                levels.map((level) {
                  return ChoiceChip(
                    label: Text(level.toUpperCase()),
                    selected: selectedLevel == level,
                    onSelected: (selected) {
                      setState(() {
                        selectedLevel = selected ? level : null;
                        selectedCourses.clear();
                      });
                      if (selected) {
                        _loadCoursesForLevel(level);
                      }
                    },
                  );
                }).toList(),
          ),

          const SizedBox(height: 20),

          // Courses List
          if (selectedLevel != null) ...[
            const Text(
              'Available Courses:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            if (isLoadingCourses)
              const Center(child: CircularProgressIndicator())
            else if (levelCourses[selectedLevel!]?.isEmpty ?? true)
              const Text('No courses available for this level')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: levelCourses[selectedLevel!]!.length,
                  itemBuilder: (context, index) {
                    final course = levelCourses[selectedLevel!]![index];
                    final isSelected = selectedCourses.contains(
                      course['course_id'],
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedCourses.add(course['course_id']);
                              } else {
                                selectedCourses.remove(course['course_id']);
                              }
                            });
                          },
                        ),
                        title: Text(course['course_name']),
                        subtitle: Text(
                          '${course['course_id']} • ${course['credits']} credits',
                        ),
                        trailing: Text(
                          course['status'] ?? 'compulsory',
                          style: TextStyle(
                            color:
                                course['status'] == 'compulsory'
                                    ? Colors.red
                                    : Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Enroll Button
            if (selectedCourses.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enrollInSelectedCourses,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3C3889),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Enroll in Selected Courses',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadCoursesForLevel(String level) async {
    setState(() {
      isLoadingCourses = true;
    });

    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showError('Please log in first');
      setState(() {
        isLoadingCourses = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppRoutes.url}/umsapp/courses/$level'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final courses = jsonDecode(response.body);
        setState(() {
          levelCourses[level] = List<dynamic>.from(courses);
        });
      } else {
        _showError('Failed to load courses for $level');
        if (response.statusCode == 401) {
          _showError('Please log in again');
        }
      }
    } catch (e) {
      _showError('Error loading courses: $e');
    } finally {
      setState(() {
        isLoadingCourses = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _enrollInSelectedCourses() async {
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      _showError('Please log in first');
      return;
    }

    bool allSuccessful = true;
    int successCount = 0;

    for (String courseId in selectedCourses) {
      try {
        final response = await http.post(
          Uri.parse('${AppRoutes.url}/umsapp/enroll'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'course_name': courseId,
            'period': widget.currentSemester['period'],
            'year': widget.currentSemester['year'],
          }),
        );

        if (response.statusCode == 200) {
          successCount++;
        } else {
          allSuccessful = false;
          print('Failed to enroll in $courseId: ${response.statusCode}');
          if (response.statusCode == 401) {
            _showError('Please log in again');
            break;
          }
        }
      } catch (e) {
        allSuccessful = false;
        print('Error enrolling in $courseId: $e');
      }
    }

    if (mounted) {
      if (allSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully enrolled in $successCount courses'),
          ),
        );
        widget.onEnrollSuccess();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Enrolled in $successCount courses, but some failed',
            ),
          ),
        );
      }
    }
  }
}

// -------------------- WIDGETS --------------------

Widget _SectionTitle({required String label, required double screenWidth}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: TextStyle(
        fontSize: screenWidth * 0.05,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class CustomBox extends StatelessWidget {
  final Color color;
  final String courseName;
  final String courseId;
  final int credit;
  final String status;
  final String level;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const CustomBox({
    super.key,
    required this.color,
    required this.courseName,
    required this.courseId,
    required this.credit,
    required this.status,
    required this.level,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(courseName),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Course ID: $courseId"),
                    Text("Credits: $credit"),
                    Text("Status: $status"),
                    Text("Level: $level"),
                  ],
                ),
                actions: [
                  TextButton(onPressed: onDelete, child: const Text('Delete')),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                courseName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size(80, 35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 0,
              ),
              child: const Text('Open', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
