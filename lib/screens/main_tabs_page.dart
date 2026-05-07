import 'package:flutter/material.dart';
import 'card_reveal_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'wheel_page.dart';

/// Main tabs: Wheel (legacy), Cards (new reveal flow), History, Profile.
///
/// The Cards tab is shipped alongside the Wheel — the two are functionally
/// equivalent decision flows; keeping both lets users (and us) compare.
class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const WheelPage(),
    const CardRevealPage(),
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
            icon: Icon(Icons.style),
            label: 'Cards',
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