import 'package:flutter/material.dart';
import 'package:sugmps/core/widgets/bottom_nav_bar.dart';
import 'package:sugmps/pages/Homepage.dart'; // Your homepage
import 'package:sugmps/pages/timetable.dart'; // Your timetable page
import 'package:sugmps/pages/statistics.dart'; // Create this placeholder

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({Key? key}) : super(key: key);

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  // Your page routes
  final List<Widget> _pages = [
    const Homepage(), // Your existing homepage
    const TimetablePage(), // Your timetable page
    const StatisticsPage(), // Create this placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: BottomNavItems.defaultItems,
      ),
    );
  }
}
