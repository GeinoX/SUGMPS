import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/Student/Authen/login.dart';
import 'package:sugmps/Student/Authen/registration.dart';
import 'package:sugmps/Student/MSs/Attendance/Studattpage.dart';
import 'package:sugmps/Student/MSs/Attendance/course_display.dart';
import 'package:sugmps/Student/MSs/Courses/course_page.dart';
import 'package:sugmps/Student/MSs/homepage.dart';
import 'package:sugmps/Student/MSs/notifications/bulletin.dart';
import 'package:sugmps/Student/MSs/timetable.dart';
import 'package:sugmps/usertype.dart';
import 'package:sugmps/utils/teacher_course_adapter.dart';
import 'routes.dart';
import 'OSs/styles.dart';
import 'OSs/os1.dart';
import 'services/auth_service.dart';
import 'utils/jwt_helper.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sugmps/utils/course_adapter.dart';
import 'package:sugmps/utils/attendancetemp_adapter.dart';
import 'package:sugmps/utils/notification_adapter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make status bar consistent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.background,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters safely (avoids double registration)
  if (!Hive.isAdapterRegistered(CourseAdapter().typeId)) {
    Hive.registerAdapter(CourseAdapter());
  }
  if (!Hive.isAdapterRegistered(AttendanceAdapter().typeId)) {
    Hive.registerAdapter(AttendanceAdapter());
  }

  if (!Hive.isAdapterRegistered(NotificationModelAdapter().typeId)) {
    Hive.registerAdapter(NotificationModelAdapter());
  }

  if (!Hive.isAdapterRegistered(TeacherCourseAdapter().typeId)) {
    Hive.registerAdapter(TeacherCourseAdapter());
  }

  // Open boxes
  await Hive.openBox<Course>('courses');
  await Hive.openBox<Attendance>('attendance');
  await Hive.openBox<NotificationModel>('notifications');
  await Hive.openBox<TeacherCourse>('teacher_courses');

  // Check onboarding
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  String startPage = AppRoutes.login; // default

  final accessToken = prefs.getString('accessToken');
  final refreshToken = prefs.getString('refreshToken');

  // Token check & refresh
  if (accessToken != null && refreshToken != null) {
    if (!JwtHelper.isExpired(accessToken)) {
      startPage = AppRoutes.homepage;
    } else {
      try {
        final authService = AuthService(baseUrl: AppRoutes.url);
        final newTokens = await authService.refresh(refreshToken);

        await prefs.setString('accessToken', newTokens['access']);
        await prefs.setString('refreshToken', newTokens['refresh']);

        startPage = AppRoutes.teacherhomepage;
      } catch (_) {
        startPage = AppRoutes.login;
      }
    }
  }

  runApp(MyApp(seenOnboarding: seenOnboarding, startPage: startPage));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  final String startPage;

  const MyApp({
    super.key,
    required this.seenOnboarding,
    required this.startPage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: seenOnboarding ? _getStartPage(startPage) : const OS1(),
      onGenerateRoute: (settings) {
        WidgetBuilder builder;
        switch (settings.name) {
          case AppRoutes.os1:
            builder = (_) => const OS1();
            break;
          case AppRoutes.usertype:
            builder = (_) => const UserType();
            break;
          case AppRoutes.registration:
            builder = (_) => const Registration();
            break;
          case AppRoutes.login:
            builder = (_) => const Login();
            break;
          case AppRoutes.homepage:
            builder = (_) => const Homepage();
            break;
          case AppRoutes.coursepage:
            builder = (_) => const Coursepage();
            break;
          case AppRoutes.coursedisplay:
            builder = (_) => const CourseListPage();
            break;
          case AppRoutes.notifications:
            builder = (_) => const NotificationsPage();
            break;
          case AppRoutes.timetablepage:
            builder = (_) => const TimetablePage();
            break;

          default:
            throw Exception('Invalid route: ${settings.name}');
        }
        return PageRouteBuilder(
          pageBuilder: (context, __, ___) => builder(context),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    );
  }

  Widget _getStartPage(String route) {
    switch (route) {
      case AppRoutes.login:
        return const Login();
      case AppRoutes.homepage:
        return const Homepage();
      default:
        return const Login();
    }
  }
}
