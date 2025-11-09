import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugmps/Authentication/login.dart';
import 'package:sugmps/Authentication/registration.dart';
import 'package:sugmps/Attendance/Studattpage.dart';
import 'package:sugmps/Attendance/course_display.dart';
import 'package:sugmps/core/widgets/main_navigation.dart'; // Add this import
import 'package:sugmps/pages/homepage.dart';
import 'package:sugmps/pages/timetable.dart';
import 'package:sugmps/core/adapters/teacher_course_adapter.dart';
import 'core/routes/routes.dart';
import 'OSs/styles.dart';
import 'OSs/os1.dart';
import 'services/auth_service.dart';
import 'core/utils/jwt_helper.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sugmps/core/adapters/course_adapter.dart';
import 'package:sugmps/core/adapters/attendancetemp_adapter.dart';
import 'package:sugmps/core/adapters/notification_adapter.dart';

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
          case AppRoutes.registration:
            builder = (_) => const Registration();
            break;
          case AppRoutes.login:
            builder = (_) => const Login();
            break;
          case AppRoutes.homepage:
            builder =
                (_) =>
                    const MainNavigationWrapper(); // ✅ Changed to MainNavigationWrapper
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
        return const MainNavigationWrapper(); // ✅ Changed to MainNavigationWrapper
      default:
        return const Login();
    }
  }
}
