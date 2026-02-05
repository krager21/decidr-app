import 'package:flutter/material.dart';
import 'wheel_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

/// Main page with tabs for wheel, history, and profile
class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  _MainTabsPageState createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const WheelPage(),
    const HistoryPage(),
    const ProfilePage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shuffle),
            label: 'Wheel',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}