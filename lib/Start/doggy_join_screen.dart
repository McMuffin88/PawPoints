// DoggyJoinScreen – moderner Look mit QR-Code Fokus & Login-Link
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pawpoints/Start/Doggy_register_screen.dart';
import 'doggy_profile_setup_screen.dart';
import 'doggy_login_screen.dart';
import '/Start/qr_stub.dart'
  if (dart.library.io) 'mobile_qr_screen.dart';

class DoggyJoinScreen extends StatefulWidget {
  const DoggyJoinScreen({super.key});

  @override
  State<DoggyJoinScreen> createState() => _DoggyJoinScreenState();
}

class _DoggyJoinScreenState extends State<DoggyJoinScreen> {
  final TextEditingController _codeController = TextEditingController();

  void _goAsStray() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DoggyProfileSetupScreen(withoutHerrchen: true),
      ),
    );
  }

  void _useCodeManually() {
    final code = _codeController.text.trim();
    if (code.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoggyProfileSetupScreen(
            withoutHerrchen: false,
            invitationCode: code,
          ),
        ),
      );
    }
  }

  void _startQrScan() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR-Scan ist nur auf Mobilgeräten verfügbar.')),
      );
    } else {
      final code = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MobileQRScreen()),
      );
      if (code != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoggyProfileSetupScreen(
              withoutHerrchen: false,
              invitationCode: code,
            ),
          ),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DoggyLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Doggy beitreten')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Willkommen bei PawPoints 🐾',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Herrchen über QR-Code finden'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: _startQrScan,
              ),
              const SizedBox(height: 32),
              const Text(
                'Oder gib einen Einladungscode ein:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: screenWidth * 0.5,
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    hintText: 'Einladungscode',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _useCodeManually,
                child: const Text('Code verwenden'),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.pets),
                label: const Text('Als Streuner losziehen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DoggyRegisterScreen()),
  );
},


              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToLogin,
                child: const Text('Ich habe schon einen Doggy-Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}