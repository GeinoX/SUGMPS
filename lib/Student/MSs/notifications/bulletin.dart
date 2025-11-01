import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/routes.dart';
import 'package:sugmps/services/notification_socket.dart';
import 'package:sugmps/utils/notification_adapter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationSocketService _socketService = NotificationSocketService();
  late Box<NotificationModel> _notificationBox;

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();

  bool _hiveReady = false;

  @override
  void initState() {
    super.initState();
    _initializeHiveAndSocket();
  }

  Future<void> _initializeHiveAndSocket() async {
    // Open the Hive box (already registered in main)
    _notificationBox = Hive.box<NotificationModel>('notifications');

    setState(() => _hiveReady = true);

    // Initialize WebSocket
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    _socketService.connect(token);

    _socketService.onMessage = (data) async {
      try {
        final notif = NotificationModel(
          message: data['message'] ?? '',
          sender: data['sender'] ?? 'Unknown',
          timestamp: DateTime.parse(
            data['timestamp'] ?? DateTime.now().toIso8601String(),
          ),
          course: data['course']?.toString() ?? '',
        );

        await _notificationBox.add(notif);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🔔 New message from ${notif.sender}"),
            backgroundColor: const Color(0xFF3C3889),
          ),
        );
      } catch (e) {
        debugPrint("Error saving notification: $e");
      }
    };
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _msgController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  String formatTime(DateTime dt) {
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  void _showSendDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Send Notification"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _msgController,
                decoration: const InputDecoration(
                  hintText: "Enter notification message...",
                  prefixIcon: Icon(Icons.message_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _courseController,
                decoration: const InputDecoration(
                  hintText: "Enter course ID...",
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (_msgController.text.isNotEmpty &&
                    _courseController.text.isNotEmpty) {
                  _socketService.sendNotification(
                    _msgController.text.trim(),
                    int.parse(_courseController.text.trim()),
                  );
                  _msgController.clear();
                  _courseController.clear();
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.send),
              label: const Text("Send"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE77B22),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hiveReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double scale = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
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
        backgroundColor: const Color(0xFF3C3889),
        actions: [
          IconButton(icon: const Icon(Icons.send), onPressed: _showSendDialog),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: ValueListenableBuilder(
          valueListenable: _notificationBox.listenable(),
          builder: (context, Box<NotificationModel> box, _) {
            final notifications = box.values.toList().reversed.toList();

            if (notifications.isEmpty) {
              return const Center(child: Text("No notifications yet..."));
            }

            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Container(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: screenWidth * 0.12,
                        height: screenWidth * 0.12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE77B22),
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.03,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Course: ${notif.course}",
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 15 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              "From ${notif.sender}",
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              formatTime(notif.timestamp),
                              style: TextStyle(
                                fontSize: 12 * scale,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
