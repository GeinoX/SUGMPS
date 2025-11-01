import 'package:flutter/material.dart';
import 'package:sugmps/routes.dart';
import 'package:sugmps/services/fetch_service.dart';
import 'course_enroll.dart';

class Coursepage extends StatefulWidget {
  const Coursepage({super.key});

  @override
  _CoursepageState createState() => _CoursepageState();
}

class _CoursepageState extends State<Coursepage> {
  bool isLoading = false;

  Future<void> loadCourses(BuildContext context, String levelSem) async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.fetchCourses(levelSem);
      if (!mounted) return;

      Navigator.pop(context); // close modal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CourseListPage(courses: data, levelSem: levelSem),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading courses")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.homepage);
          },
        ),
        title: Text("Courses"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder:
                      (context) => _LevelModal(
                        onSelect: (levelSem) {
                          loadCourses(context, levelSem);
                        },
                      ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(255, 255, 255, 0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                'Enroll',
                style: TextStyle(
                  fontSize: 15,
                  color: Color.fromRGBO(0, 0, 0, 1),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Color.fromRGBO(255, 255, 255, 0.95),
      body: Center(
        child:
            isLoading
                ? CircularProgressIndicator()
                : Text(
                  "Choose a level to view courses",
                  style: TextStyle(
                    color: Color.fromRGBO(0, 0, 0, 0.5),
                    fontSize: 18,
                  ),
                ),
      ),
    );
  }
}

class _LevelModal extends StatelessWidget {
  final Function(String) onSelect;

  const _LevelModal({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("Choose Level", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            _Levelbox(
              label: "Level 1 Semester 1",
              onTap: () => onSelect("l1s1"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 1 Semester 2",
              onTap: () => onSelect("l1s2"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 2 Semester 1",
              onTap: () => onSelect("l2s1"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 2 Semester 2",
              onTap: () => onSelect("l2s2"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 2 Semester 4",
              onTap: () => onSelect("l2s4"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 3 Semester 1",
              onTap: () => onSelect("l3s1"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 3 Semester 2",
              onTap: () => onSelect("l3s2"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 4 Semester 1",
              onTap: () => onSelect("l4s1"),
            ),
            const SizedBox(height: 15),
            _Levelbox(
              label: "Level 4 Semester 2",
              onTap: () => onSelect("l4s2"),
            ),
          ],
        ),
      ),
    );
  }
}

class _Levelbox extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Levelbox({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 300,
        decoration: BoxDecoration(
          color: Color.fromRGBO(185, 240, 236, 0.498),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 18))),
      ),
    );
  }
}
