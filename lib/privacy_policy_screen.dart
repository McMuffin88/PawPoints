import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> privacySections = [
      {
        "title": "1. Verantwortliche Stelle",
        "content":
            "Verantwortlich für die Verarbeitung personenbezogener Daten in dieser App ist:\n[Name/Firma eintragen]\n[E-Mail-Adresse eintragen]\n[Anschrift (optional)]"
      },
      {
        "title": "2. Allgemeines zur Datenverarbeitung",
        "content":
            "Die App PawPoints wurde mit besonderem Fokus auf Diskretion und Datenschutz entwickelt. Es werden nur die Daten erhoben, verarbeitet und gespeichert, die für den Betrieb der App oder für Premium-Inhalte unbedingt notwendig sind."
      },
      {
        "title": "3. Art der verarbeiteten Daten",
        "content":
            "• Profilinformationen wie frei gewählter Nutzername/Nickname, optional Profilbild, Lieblingsfarbe, PLZ/Ort, Pronomen\n• App-spezifische Daten wie Aufgaben, Belohnungen, Punktestände, Berechtigungen und Verbindungsstatus\n• Es werden keine sensiblen personenbezogenen Daten wie echter Name, Adresse oder Telefonnummer zwangsweise erhoben."
      },
      {
        "title": "4. Verarbeitungszwecke",
        "content":
            "• Bereitstellung und Personalisierung der App\n• Verwaltung der Nutzerprofile und Beziehungen (Doggy/Herrchen)\n• Aufgabenmanagement, Punkteverwaltung, Shop-Funktionen\n• Optionale Nutzung von Premium-Features"
      },
      {
        "title": "5. Premium-Funktionen und Zahlungsabwicklung",
        "content":
            "Premium-Inhalte oder -Funktionen werden ausschließlich über den Google Play Store oder Apple App Store angeboten. Die Zahlungsabwicklung und Identitätsprüfung erfolgen ausschließlich über die jeweiligen Stores. Für Premium-Käufe werden keine zusätzlichen personenbezogenen Daten (wie echter Name oder Adresse) durch PawPoints erhoben oder gespeichert. Es werden lediglich technische Informationen zur Freischaltung der Premium-Funktionen gespeichert (z.B. Purchase-Token, Account-ID)."
      },
      {
        "title": "6. Zugriff auf Daten",
        "content":
            "Deine Daten werden nicht an Dritte weitergegeben. Eine Übertragung deiner Daten erfolgt nur, sofern dies gesetzlich vorgeschrieben ist oder du ausdrücklich zustimmst."
      },
      {
        "title": "7. Speicherung und Sicherheit",
        "content":
            "Alle personenbezogenen Daten werden sicher gespeichert und verschlüsselt, soweit dies technisch möglich ist. Optionaler PIN-Schutz kann aktiviert werden. Die App ist so konzipiert, dass möglichst wenige Rückschlüsse auf deine Identität möglich sind."
      },
      {
        "title": "8. Firebase und Drittanbieter",
        "content":
            "Die App nutzt [Firebase/Google-Services] für bestimmte Funktionen (z.B. Authentifizierung, Speicherung, ggf. Push-Nachrichten). Es gelten hierfür ergänzend die Datenschutzbestimmungen von Google/Firebase:\nhttps://firebase.google.com/support/privacy"
      },
      {
        "title": "9. Rechte der Nutzer",
        "content":
            "Du hast das Recht auf Auskunft, Berichtigung, Löschung und Einschränkung deiner gespeicherten Daten. Auf Wunsch kannst du deine Daten einsehen, exportieren oder löschen lassen (Anfrage per E-Mail an [deine E-Mail-Adresse])."
      },
      {
        "title": "10. Änderungen der Datenschutzbestimmungen",
        "content":
            "Wir behalten uns vor, diese Datenschutzerklärung bei Bedarf anzupassen. Über wesentliche Änderungen wirst du in der App informiert."
      },
      {
        "title": "11. Kontakt",
        "content":
            "Bei Fragen zum Datenschutz oder zur Ausübung deiner Rechte wende dich bitte per E-Mail an:\n[deine.email@domain.com]"
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenschutzbestimmungen'),
      ),
      body: SafeArea(
        child: Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: privacySections.length,
            itemBuilder: (context, index) {
              final section = privacySections[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section['content']!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
