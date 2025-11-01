import 'package:hive/hive.dart';

part 'notification_adapter.g.dart'; // Hive will generate this

@HiveType(typeId: 2)
class NotificationModel extends HiveObject {
  @HiveField(0)
  String message;

  @HiveField(1)
  String sender;

  @HiveField(2)
  String course;

  @HiveField(3)
  DateTime timestamp;

  NotificationModel({
    required this.message,
    required this.sender,
    required this.course,
    required this.timestamp,
  });
}
