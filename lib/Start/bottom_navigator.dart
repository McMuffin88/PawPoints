import 'package:flutter/material.dart';
import '../herrchen_screen.dart';
import '../doggy_screen.dart';
import '../Drawer_herrchen/herrchen_profile_screen.dart';
import '../Drawer_Doggy/doggy_profile_screen.dart'; // Import für Doggy's Profil

class BottomNavigator extends StatefulWidget {
  final String role; // Rolle "doggy" oder "herrchen"

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

    if (widget.role == "doggy") {
      // BILDSCHIRME FÜR "DOGGY" ANPASSEN: DoggyScreen erhält eine Callback-Funktion
      _screens = [
        DoggyScreen(onProfileTap: () => _onItemTapped(1)), // Hier wird die Callback-Funktion übergeben
        const DoggyProfileScreen(),
      ];
    } else {
      // BILDSCHIRME FÜR "HERRCHEN" ANPASSEN (unverändert)
      _screens = [
        HerrchenScreen(onProfileTap: () => _onItemTapped(1)),
        const HerrchenProfileScreen(),
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
    // NAVIGATIONSELEMENTE FÜR "DOGGY" UND "HERRCHEN" ANPASSEN
    final List<BottomNavigationBarItem> items = widget.role == "doggy"
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ]
        : const [
            // Items für 'herrchen' (unverändert)
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ];

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}
