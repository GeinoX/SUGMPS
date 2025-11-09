import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/OSs/styles.dart';
import 'package:sugmps/routes.dart';
import 'attpage2.dart'; // 👈 ensure this import is correct

class StudentAttendancePage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentAttendancePage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  int totalSessions = 0;
  int attendedCount = 0;
  int justifiedCount = 0;
  int missedCount = 0;
  bool isLoading = true;

  List<Map<String, dynamic>> attendanceDays = [];

  final String baseUrl = AppRoutes.url;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    try {
      setState(() => isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null) throw Exception("No access token found");

      // 🔹 Fetch summary
      final summaryUrl = Uri.parse(
        "$baseUrl/umsapp/get_student_att/${widget.courseId}/",
      );
      final summaryRes = await http.get(
        summaryUrl,
        headers: {"Authorization": "Bearer $token"},
      );

      if (summaryRes.statusCode == 200) {
        final summaryData = json.decode(summaryRes.body);
        if (summaryData is Map<String, dynamic>) {
          totalSessions = summaryData["total_sessions"] ?? 0;
          attendedCount = summaryData["attendance_count"] ?? 0;
          justifiedCount = 0;
          missedCount = totalSessions - attendedCount;
        } else {
          print("Summary response is not a Map!");
        }
      }

      // 🔹 Fetch daily attendance
      final dailyUrl = Uri.parse(
        "$baseUrl/umsapp/attendance/student/${widget.courseId}/",
      );
      final dailyRes = await http.get(
        dailyUrl,
        headers: {"Authorization": "Bearer $token"},
      );

      if (dailyRes.statusCode == 200) {
        final dailyData = json.decode(dailyRes.body);
        if (dailyData is List) {
          attendanceDays =
              dailyData.map<Map<String, dynamic>>((dayData) {
                return {
                  "day": dayData['day'] ?? 0,
                  "session_id": dayData['session_id'] ?? "",
                  "status": dayData['status'] ?? "Missed",
                };
              }).toList();
        } else {
          print("Daily attendance response is not a List!");
        }
      }
    } catch (e) {
      print("Error fetching attendance: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Navigate to BLE Scanning Page
  Future<void> _openScanPage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AttendanceBlePage(
              courseId: widget.courseId,
              courseName: widget.courseName,
              token: token,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendance,
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 🔹 Summary Row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryColumn("Total", totalSessions),
                              _buildSummaryColumn("Attended", attendedCount),
                              _buildSummaryColumn("Missed", missedCount),
                              _buildSummaryColumn("Justified", justifiedCount),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 🔹 Attendance Percentage
                        if (totalSessions > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Attendance Percentage",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value:
                                            totalSessions > 0
                                                ? attendedCount / totalSessions
                                                : 0,
                                        backgroundColor: Colors.grey[300],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              (attendedCount / totalSessions) >=
                                                      0.75
                                                  ? Colors.green
                                                  : (attendedCount /
                                                          totalSessions) >=
                                                      0.5
                                                  ? Colors.orange
                                                  : Colors.red,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  "${totalSessions > 0 ? ((attendedCount / totalSessions) * 100).toStringAsFixed(1) : 0}%",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),

                        // 🔹 Daily Attendance List
                        if (attendanceDays.isEmpty)
                          const Text(
                            "No attendance records available.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Daily Attendance:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...attendanceDays.map((dayData) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Day ${dayData['day']}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (dayData['session_id'] != null &&
                                              dayData['session_id'].isNotEmpty)
                                            Text(
                                              "Session: ${dayData['session_id'].toString().substring(0, 8)}...",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            dayData['status'],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          dayData['status'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
      ),

      // ✅ Floating Scan Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanPage,
        label: const Text("Scan Attendance"),
        icon: const Icon(Icons.qr_code_scanner),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'attended':
        return Colors.green;
      case 'justified':
        return Colors.orange;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryColumn(String title, int value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
