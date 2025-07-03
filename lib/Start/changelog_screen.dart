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
      },
      {
        "version": "0.0.386",
        "changes": [
          "Schriftgröße ändern eingefügt – noch Anpassungen nötig",
          "Systemweite Anpassung möglich",
          "Anpassung Reiter \"Einstellungen\" im Drawer",
          "Light & Dark Option eingeführt",
          "Herrchen Main Screen angepasst – zeigt jetzt den News Feed der Doggys an, wenn vorhanden (Bug bekannt: Farbe der Pfote etc.)",
          "Bug behoben: \"Aufgaben\" zeigt jetzt korrekt \"Meine Aufgaben\"",
          "Bug behoben: \"Profil\" – Name erscheint jetzt korrekt über dem Bild"
        ]
      },
      {
        "version": "0.0.387",
        "changes": [
          "Bug behoben: \"Anderes\" – App liegt im Statusbildschirm",
          "Bugs melden überarbeitet – Bugs haben jetzt ID-Nummern",
          "Update Registrierung: Profilbild wird jetzt stärker hervorgehoben",
          "Bug behoben: Premiumfeature mehrere Doggys funktioniert jetzt korrekt",
          "Bug behoben: Beim Annehmen eines Doggys wurde das Profilbild nicht mitgespeichert – führte dazu, dass der Doggy ohne Profilbild beim Herrchen angezeigt wurde",
          "Im Herrchenscreen wird der Doggy jetzt mit der Lieblingsfarbe umrandet, um anzuzeigen, welcher Doggyfeed ausgewählt ist",
          "Bug behoben: In der Aufgabenansicht wurde der Name des Doggys nicht angezeigt",
          "Anpassung der Abstände in der Aufgabenerstellung des Herrchens",
          "Anpassung: Zentrierung der Doggys in der Shop-Anzeige",
          "#2 Bug behoben: Endzeit wird nun live bei Änderung angezeigt"
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
