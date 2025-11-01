import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sugmps/routes.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  List<Map<String, dynamic>> _timetable = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  // -------------------- FETCH TIMETABLE --------------------
  Future<void> _fetchTimetable() async {
    final url = Uri.parse('${AppRoutes.url}/umsapp/timetable');

    try {
      final response = await http.get(url);

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

        setState(() {
          _timetable = data;
          _loading = false;
        });
      } else {
        print('Request failed: ${response.statusCode}');
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error: $e');
      setState(() => _loading = false);
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Timetable'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.homepage);
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.homepage);
            }
          },
        ),
      ),
      body:
          validDays.isEmpty
              ? const Center(
                child: Text(
                  'No classes available for this week.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children:
                      validDays.map((day) {
                        final courses = coursesByDay[day]!;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              day,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children:
                                courses.map((course) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 10,
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          flex: 2,
                                          child: Text(
                                            course['course_name']
                                                .toString(), // <-- UPDATED TO USE course_name
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          child: Text(
                                            '${course['start_time'].toString()} - ${course['end_time'].toString()}',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          child: Text(
                                            course['hall'].toString(),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        );
                      }).toList(),
                ),
              ),
    );
  }
}
