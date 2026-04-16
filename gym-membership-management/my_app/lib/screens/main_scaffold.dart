import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';
import 'member_list_screen.dart';
import 'voice_log_screen.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(),
      MemberListScreen(),
      VoiceLogScreen(),
      ProfileScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.background,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.secondaryText,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
