import 'package:flutter/material.dart';

class MobileQRScreen extends StatelessWidget {
  const MobileQRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nicht unterstützt')),
      body: const Center(
        child: Text('QR-Code-Scan ist nur auf mobilen Geräten verfügbar.'),
      ),
    );
  }
}
