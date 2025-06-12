// lib/Settings/premium_screen.dart
import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium-Funktionen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: ListTile(
              leading: const Icon(Icons.pets, size: 32, color: Colors.brown),
              title: const Text('Streuner-Suche'),
              subtitle: const Text('Finde herrenlose Hunde in deiner Umgebung'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diese Funktion ist bald verfügbar!')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Weitere Premium-Inhalte folgen...')),
        ],
      ),
    );
  }
}
