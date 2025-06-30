import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> faqData = const [
    {
      "question": "Was ist PawPoints?",
      "answer":
          "PawPoints ist eine App für die Human Pupplay-/Dogplay-Community. Sie richtet sich ausschließlich an Erwachsene (18+), die in konsensuellen Rollen als „Doggy“ (Pup) oder „Herrchen“ (Handler) spielerische Beziehungen erleben und verwalten möchten – mit Fokus auf Diskretion, Datenschutz und Individualisierung."
    },
    {
      "question": "Ist PawPoints für echte Tiere oder Tierpflege gedacht?",
      "answer":
          "Nein! PawPoints richtet sich ausschließlich an Menschen innerhalb der Human Pupplay-/Dogplay- und BDSM-Community. Für echte Hunde oder Tierpflege ist sie nicht geeignet."
    },
    {
      "question": "Wie funktioniert die Rollenwahl?",
      "answer":
          "Jede Nutzer*in wählt beim ersten Start eine Rolle („Doggy“ oder „Herrchen“). Diese Entscheidung gilt dauerhaft und kann nur durch einen kompletten Reset geändert werden."
    },
    {
      "question": "Wie kann ich mich mit meinem Herrchen oder Doggy verbinden?",
      "answer":
          "Doggy verbindet sich über einen Einladungscode oder QR-Code mit einem Herrchen. Das Herrchen erstellt Einladungscodes, um Doggys zur Verbindung einzuladen und zu verwalten. Die Verbindung kann jederzeit über die App getrennt werden (mit Bestätigung)."
    },
    {
      "question": "Wie funktioniert das Aufgaben- und Punktesystem?",
      "answer":
          "Herrchen erstellt Aufgaben, verteilt Belohnungen oder Bestrafungen und behält die Historie im Blick. Doggy sieht zugewiesene Aufgaben, kann sie als erledigt markieren und sammelt dafür Punkte. Diese Punkte können im Shop gegen Belohnungen eingelöst werden."
    },
    {
      "question": "Was sehe ich als Doggy im Shop?",
      "answer":
          "Doggy sieht im Shop nur die Belohnungen, die mit Punkten eingelöst werden können. Bestrafungen sind für Doggys nicht sichtbar, außer sie werden explizit zugewiesen."
    },
    {
      "question": "Was sind die Berechtigungen für Doggys?",
      "answer":
          "Herrchen kann für jeden Doggy individuell einstellen, welche Rechte dieser hat (z. B. eigene Aufgaben anlegen/bearbeiten, Belohnungen vorschlagen, Regeln ändern usw.). Standardmäßig sind die meisten Rechte deaktiviert."
    },
    {
      "question": "Welche Sicherheits- und Datenschutzfunktionen gibt es?",
      "answer":
          "Es gibt einen optionalen PIN-Schutz für den App-Zugang, einen Diskretmodus mit dezentem Look, optional anderem App-Icon und ausblendbaren Inhalten. Außerdem werden keine sensiblen Daten an Dritte weitergegeben."
    },
    {
      "question": "Was sind Premium-Features?",
      "answer":
          "Premium bietet unter anderem exklusive Avatare, Themes, Shop-Extras, Exportfunktionen und Community-Features. Details findest du im Bereich „Premium“ der App."
    },
    {
      "question": "Kann ich die App auf Deutsch und Englisch nutzen?",
      "answer":
          "Mehrsprachigkeit ist geplant, derzeit ist die App vorwiegend auf Deutsch verfügbar."
    },
    {
      "question": "Wie gebe ich Feedback oder wünsche mir neue Features?",
      "answer":
          "Über die integrierte Feedback-Funktion in der App kannst du direkt Wünsche, Anregungen oder Probleme melden."
    },
    {
      "question": "Wer kann PawPoints nutzen?",
      "answer":
          "Nur volljährige Personen (18+), die sich für die Human Pupplay-/Dogplay-Community interessieren und sich an die Grundregeln für Konsens, Diskretion und Datenschutz halten."
    },
    {
      "question": "Wie kann ich meinen Account oder meine Rolle zurücksetzen?",
      "answer":
          "Ein Rollenwechsel ist nur durch einen kompletten Reset möglich. Dafür gibt es eine entsprechende Funktion in den Einstellungen."
    },
    {
      "question": "Was tue ich bei Problemen mit der Verbindung oder beim Shop?",
      "answer":
          "Bitte prüfe zuerst, ob deine Internetverbindung stabil ist. Bei technischen Problemen hilft dir der Support-Bereich in der App oder du kontaktierst uns per E-Mail."
    },
    {
      "question": "Wo finde ich weitere Infos zu Datenschutz und Impressum?",
      "answer":
          "Den Bereich Datenschutz und Impressum findest du im Support- oder Einstellungen-Menü der App."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FAQ"),
      ),
      body: ListView.builder(
        itemCount: faqData.length,
        itemBuilder: (context, index) {
          final item = faqData[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: ExpansionTile(
                title: Text(
                  item["question"]!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      item["answer"]!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
