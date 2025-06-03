import 'package:flutter/material.dart';
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
      theme: ThemeData(
        colorSchemeSeed: Colors.brown,
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
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role'); // "herrchen" oder "doggy"

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
    // sonst: auf dieser Seite bleiben → Auswahl anzeigen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PawPoints')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Wer bist du?', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Ich bin das Herrchen'),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString('user_role', 'herrchen');
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.pets),
              label: const Text('Ich bin der Doggy'),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString('user_role', 'doggy');
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DoggyJoinScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
