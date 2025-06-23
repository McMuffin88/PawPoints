import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roadmap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader(icon: Icons.bug_report, title: 'Bugfixes'),
          _RoadmapCard(id: 'bug_profile_menu', text: '🐞 Beim Profilanpassen das Burgermenü durch das Profilbild ersetzen'),

          SizedBox(height: 16),
          _SectionHeader(icon: Icons.task_alt, title: 'Nächste To-Dos'),
          _RoadmapCard(
            id: 'todo_doggy_view',
            text: '📌 Doggy-Ansicht / Doggy Screen anpassen, sodass Bestrafungen gefiltert werden und Aufgaben durchkommen',
          ),
          _RoadmapCard(
            id: 'todo_shop_view',
            text: '📌 Shop-Ansicht für Doggys mit Belohnungen füllen',
          ),
          _RoadmapCard(
            id: 'todo_expandable_tasks',
            text: '📌 Ausklappbare Aufgaben in der Doggy-Ansicht, damit vollständige Belohnungen oder Bestrafungen sichtbar sind',
          ),

          SizedBox(height: 24),
          _SectionHeader(icon: Icons.auto_awesome, title: 'Features'),
          _RoadmapCard(id: 'feat_permissions', text: '✅ Berechtigungen mit echter Berechtigungslogik füllen'),
          _RoadmapCard(id: 'feat_messaging', text: '✅ Nachrichtenfunktion zwischen Doggy und Herrchen'),
          _RoadmapCard(id: 'feat_photo_proof', text: '✅ Fotobeweis-Funktion bei erledigten Aufgaben'),
          _RoadmapCard(id: 'feat_custom_message', text: '✅ Individuelle Nachricht nach Erledigung einer Aufgabe'),

          SizedBox(height: 24),
          _SectionHeader(icon: Icons.workspace_premium, title: 'Premium Extras'),
          _RoadmapCard(id: 'premium_avatars', text: '👑 Exklusive Avatare für Doggys'),
          _RoadmapCard(id: 'premium_themes', text: '👑 Premium-Hintergründe & Themes'),
          _RoadmapCard(id: 'premium_early_access', text: '👑 Frühzeitiger Zugriff auf neue Funktionen'),
          _RoadmapCard(id: 'premium_convert_points', text: '💡 Punkte in Bark / Knochen / Leckerli umwandelbar machen'),
          _RoadmapCard(id: 'premium_hide_rewards', text: '💡 Belohnungen & Bestrafungen ausblendbar machen'),
          _RoadmapCard(id: 'premium_search_doggys', text: '👑 Doggys können aktiv nach Herrchen suchen'),
          _RoadmapCard(id: 'premium_find_free_doggys', text: '👑 Herrchen können freie Doggys in ihrer Umgebung suchen'),
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

class _RoadmapCard extends StatefulWidget {
  final String id;
  final String text;

  const _RoadmapCard({required this.id, required this.text});

  @override
  State<_RoadmapCard> createState() => _RoadmapCardState();
}

class _RoadmapCardState extends State<_RoadmapCard> {
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDone = prefs.getBool(widget.id) ?? false;
    });
  }

  Future<void> _updateState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.id, value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: _isDone,
              onChanged: (value) {
                final newValue = value ?? false;
                setState(() {
                  _isDone = newValue;
                });
                _updateState(newValue);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  decoration: _isDone ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
