import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium-Funktionen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Diese Funktionen werden bald verfügbar sein:', style: TextStyle(fontSize: 18)),
          SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.star_border),
            title: Text('Erweiterte Doggy-Auswertungen'),
            subtitle: Text('Behalte Fortschritt und Motivation im Blick'),
          ),
          ListTile(
            leading: Icon(Icons.lock_open),
            title: Text('Zusätzliche Berechtigungsgruppen'),
            subtitle: Text('Noch differenziertere Aufgabenverteilung'),
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('Erweiterte Historie'),
            subtitle: Text('Mehr Einsicht in vergangene Aufgaben und Aktionen'),
          ),
          ListTile(
            leading: Icon(Icons.emoji_events),
            title: Text('Belohnungssysteme & Level'),
            subtitle: Text('Gamification für Motivation'),
          ),
        ],
      ),
    );
  }
}
