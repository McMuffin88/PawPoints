import 'package:flutter/material.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roadmap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(icon: Icons.bug_report, title: 'Bugfixes'),
          const _RoadmapCard(text: '🐞 Beim Profilanpassen das Burgermenü durch das Profilbild ersetzen'),

          const SizedBox(height: 16),
          const _SectionHeader(icon: Icons.task_alt, title: 'Nächste To-Dos'),
          const _RoadmapCard(
            text: '📌 Doggy-Ansicht / Doggy Screen anpassen, sodass Bestrafungen gefiltert werden und Aufgaben durchkommen',
          ),
          const _RoadmapCard(
            text: '📌 Shop-Ansicht für Doggys mit Belohnungen füllen',
          ),
          const _RoadmapCard(
            text: '📌 Ausklappbare Aufgaben in der Doggy-Ansicht, damit vollständige Belohnungen oder Bestrafungen sichtbar sind',
          ),

          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.auto_awesome, title: 'Features'),
          const _RoadmapCard(text: '✅ Berechtigungen mit echter Berechtigungslogik füllen'),
          const _RoadmapCard(text: '✅ Nachrichtenfunktion zwischen Doggy und Herrchen'),
          const _RoadmapCard(text: '✅ Fotobeweis-Funktion bei erledigten Aufgaben'),
          const _RoadmapCard(text: '✅ Individuelle Nachricht nach Erledigung einer Aufgabe'),

          const SizedBox(height: 24),
          const _SectionHeader(icon: Icons.workspace_premium, title: 'Premium Extras'),
          const _RoadmapCard(text: '👑 Exklusive Avatare für Doggys'),
          const _RoadmapCard(text: '👑 Premium-Hintergründe & Themes'),
          const _RoadmapCard(text: '👑 Frühzeitiger Zugriff auf neue Funktionen'),
          const _RoadmapCard(text: '💡 Punkte in Bark / Knochen / Leckerli umwandelbar machen'),
          const _RoadmapCard(text: '💡 Belohnungen & Bestrafungen ausblendbar machen'),
          const _RoadmapCard(text: '👑 Doggys können aktiv nach Herrchen suchen'),
          const _RoadmapCard(text: '👑 Herrchen können freie Doggys in ihrer Umgebung suchen'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.brown, size: 28),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  final String text;

  const _RoadmapCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
