import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF3C3889);
  static const Color secondary = Color(0xFFE77B22);
  static const Color background = Color(0xFFF8F9FA);
  static const Color whiteWithOpacity60 = Color.fromRGBO(255, 255, 255, 0.6);
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
}

class AppSizing {
  // Responsive sizing based on screen dimensions
  static double getEdgeInsets(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.05;
  }

  static double getImageHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.35;
  }

  static double getImageWidth(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.7;
  }

  static double getTitleFontSize(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.06;
  }

  static double getTextFontSize(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.04;
  }

  static double getButtonFontSize(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.045;
  }

  static double getSpacing(BuildContext context, double multiplier) {
    return MediaQuery.of(context).size.height * (0.01 * multiplier);
  }
}

class AppImages {
  static const String image1 = "assets/image1.png";
  static const String image2 = "assets/image2.png";
  static const String image3 = "assets/image3.png";
  static const String image4 = "assets/image4.png";
  static const String image5 = "assets/image5.png";
  static const String image6 = "assets/image6.png";
}

class AppText {
  static const String title1 = "Track Your Academic Performance";
  static const String text1 =
      "View your grades, monitor your GPA & CGPA in real-time, and get insights to help you stay on top of your academic journey.";
  static const String title2 = "Organize Your Schedule";
  static const String text2 =
      "View your class timetable, exam dates, and deadlines — all in one place. Stay ahead, never miss a thing.";
  static const String title3 = "Get Important Notifications";
  static const String text3 =
      "Receive instant alerts for results, assignments, announcements, and school events — right when they happen.";
  static const String title4 = "Smart Academic Insights";
  static const String text4 =
      "Get personalized suggestions based on your academic trends to improve your performance and make smarter decisions.";
  static const String title5 = "Secure & Private";
  static const String text5 =
      "Your academic records are protected. Choose what info to show, and when — your privacy is in your hands.";
  static const String title6 = "Feedback & Surveys";
  static const String text6 =
      "Share your opinions through simple surveys. Help improve learning, campus life, and support systems.";
}
