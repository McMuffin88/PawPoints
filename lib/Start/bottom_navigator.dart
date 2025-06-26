import 'package:flutter/material.dart';
import '../herrchen_screen.dart';
import '../Drawer_herrchen/herrchen_profile_screen.dart';
import '../doggy_screen.dart';
import '../Drawer_doggy/doggy_profile_screen.dart';

class BottomNavigator extends StatefulWidget {
  final String role; // <- WICHTIG!

  const BottomNavigator({super.key, required this.role});

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Tabs je nach Rolle festlegen:
    if (widget.role == "doggy") {
      _screens = [
        DoggyScreen(),          // Deine doggy_screen.dart
        DoggyProfileScreen(),   // Dein Doggy-Profil-Screen
      ];
    } else {
      _screens = [
        HerrchenScreen(),           // Deine herrchen_screen.dart
        HerrchenProfileScreen(),    // Dein Herrchen-Profil-Screen
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.brown,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Aufgaben',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
