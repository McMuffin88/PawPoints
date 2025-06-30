import 'package:flutter/material.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final changelogEntries = [
      {
        "version": "0.0.384",
        "changes": [
          "Profil angepasst - DiskretModus hinzugefügt",
          "Profilo angepasst - Lieblingsfarbe im Profil Screen angewendet",
          "Drawer angepasst (Alle Rollen) - Versionnummer jetzt aktuell + Farbe + Versionslog."
        ]
      },
      {
        "version": "0.0.385",
        "changes": [
          "App-Logo angepasst",
          "'pawpoints' zu 'Pawpoints' geändert",
          "Kritischer Bugfix: Diskreter Modus konnte umgangen werden über die in 0.0.384 implementierte Edit-Funktion im Profil",
          "FAQ hinzugefügt und mit erstem Inhalt gefüllt",
          "Nutzungsbedingungen hinzugefügt",
          "Datenschutz hinzugefügt",
          "Gemeldeten Bug behoben: Herrchen Shop – Reiterschriftfarbe bei aktivem Reiter von Schwarz auf Weiß geändert",
          "Support & Feedback hinzugefügt",
          "Support (noch ohne Funktion)",
          "\"Bug melden\" und \"gemeldete Bugs sehen\" hinzugefügt"
        ]
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Was ist neu?'),
      ),
      body: ListView.builder(
        itemCount: changelogEntries.length,
        itemBuilder: (context, index) {
          final entry = changelogEntries[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text('Version ${entry["version"]}'),
              children: (entry["changes"] as List<String>)
                  .map((c) => ListTile(title: Text("• $c")))
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}
