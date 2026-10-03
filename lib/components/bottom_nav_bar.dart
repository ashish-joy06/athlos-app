import 'package:flutter/material.dart';

/// A reusable bottom navigation bar widget that adapts to user role.
class BottomNavBar extends StatelessWidget {
  /// The currently selected index in the navigation bar.
  final int currentIndex;
  /// Callback when a navigation item is tapped.
  final ValueChanged<int> onTap;
  /// The role of the current user (affects navigation items).
  final String role;

  /// Creates a [BottomNavBar] widget.
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final List<BottomNavigationBarItem> items;

   if (role == 'Organization') {
  items = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people),
      label: 'Players',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.event),
      label: 'Tournaments',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];
} else if (role == 'Admin') {
  items = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.event_available),
      label: 'Sessions',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.emoji_events),
      label: 'Tournament',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_alt),
      label: 'Users',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];
} else {
  // Athlete / Coach fallback
  items = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today),
      label: 'Time Table',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.location_on),
      label: 'Tournaments',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];
}

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: onTap,
      items: items,
    );
  }
}
