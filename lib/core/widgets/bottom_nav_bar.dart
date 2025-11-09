import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF3C3889),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
          color: Colors.grey[600],
        ),
        items:
            widget.items
                .map((item) => item.toBottomNavigationBarItem())
                .toList(),
      ),
    );
  }
}

class BottomNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  BottomNavigationBarItem toBottomNavigationBarItem() {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Icon(activeIcon),
      label: label,
    );
  }
}

// Pre-defined navigation items for easy integration
class BottomNavItems {
  static const home = BottomNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  );

  static const timetable = BottomNavItem(
    label: 'Timetable',
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today_rounded,
  );

  static const statistics = BottomNavItem(
    label: 'Statistics',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
  );

  // Default set of items for main app navigation
  static const List<BottomNavItem> defaultItems = [home, timetable, statistics];
}
