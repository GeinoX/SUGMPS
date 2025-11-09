import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/core/adapters/course_adapter.dart';
import 'package:sugmps/services/course_service.dart';
import 'package:sugmps/core/routes/routes.dart';
import 'attpage2.dart'; // Attendance page

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final String baseUrl = AppRoutes.url;
  late final CourseService _service;
  late final Box<Course> _box;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Course>('courses');
    _service = CourseService(baseUrl: baseUrl);
    _sync(); // Initial sync
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

  /// Opens the Attendance BLE Page using only the token
  Future<void> _openAttendancePage(String courseId, String courseName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    if (token.isEmpty) {
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
              (_) => AttendanceBlePage(
                courseId: courseId,
                courseName: courseName,
                token: token, // ✅ Only token now
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.homepage),
        ),
        title: const Text('📘 My Courses'),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 2,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _sync,
            tooltip: 'Sync with server',
          ),
        ],
      ),
      body: 
      ValueListenableBuilder<Box<Course>>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          final courses = box.values.toList().cast<Course>();

          if (courses.isEmpty) {
            return RefreshIndicator(
              onRefresh: _sync,
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      'No courses saved yet.\nPull down to sync.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _sync,
            child: ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                final key = box.keyAt(index);

                final color =
                    index % 2 == 0
                        ? const Color(0xFF3C3889)
                        : const Color(0xFFE77B22);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: CustomBox(
                    color: color,
                    courseName: course.courseName,
                    courseId: course.courseId,
                    credit: course.credits,
                    status: course.status,
                    level: course.level,
                    onOpen:
                        () => _openAttendancePage(
                          course.courseId,
                          course.courseName,
                        ),
                    onDelete: () => _deleteCourse(key),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
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
        height: 80,
        padding: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
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
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
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
