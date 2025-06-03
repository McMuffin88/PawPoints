import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'doggy_join_screen.dart';
import 'herrchen_screen.dart';
import 'doggy_screen.dart';

void main() {
  runApp(const PawPointsApp());
}

class PawPointsApp extends StatelessWidget {
  const PawPointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawPoints',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [
        Locale('de', 'DE'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');

    if (role == 'herrchen') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HerrchenScreen()),
      );
    } else if (role == 'doggy') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoggyScreen()),
      );
    }
  }

  void _selectRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);

    if (role == 'herrchen') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoggyJoinScreen()),
      );
    }
  }

@override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;

  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: screenHeight * 0.3, // 👉 30% der Bildschirmhöhe
            ),
            const SizedBox(height: 32),
            const Text(
              'Wer bist du?',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _selectRole('herrchen'),
              icon: const Icon(Icons.person),
              label: const Text('Herrchen'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _selectRole('doggy'),
              icon: const Icon(Icons.pets),
              label: const Text('Doggy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
