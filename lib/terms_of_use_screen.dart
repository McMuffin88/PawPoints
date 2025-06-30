import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> terms = [
      {
        "title": "1. Geltungsbereich",
        "content":
            "Diese Nutzungsbedingungen regeln das Verhältnis zwischen den Nutzer*innen (im Folgenden „Nutzer“ bzw. „du“) und dem Betreiber der App PawPoints (im Folgenden „wir“ oder „uns“). Durch die Nutzung der App erklärst du dich mit diesen Bedingungen einverstanden."
      },
      {
        "title": "2. Zielgruppe und Nutzungsvoraussetzungen",
        "content":
            "Die App richtet sich ausschließlich an volljährige Personen (mindestens 18 Jahre). Sie ist konzipiert für die Human Pupplay-/Dogplay-Community und darf nicht für echte Tiere verwendet werden. Die Nutzung erfolgt auf eigene Verantwortung und ausschließlich im Rahmen geltender Gesetze sowie unter Wahrung gegenseitigen Konsenses."
      },
      {
        "title": "3. Registrierung und Nutzerkonto",
        "content":
            "Für die Nutzung der App ist keine separate Registrierung mit persönlichen Daten erforderlich. Jeder Nutzer wählt beim ersten Start eine feste Rolle (Herrchen oder Doggy). Diese Rolle kann nachträglich nur durch Zurücksetzen der App geändert werden."
      },
      {
        "title": "4. Inhalte und Verhaltensregeln",
        "content":
            "Es dürfen keine rechtswidrigen, beleidigenden, diskriminierenden oder gegen den Jugendschutz verstoßenden Inhalte über die App geteilt werden. Respektiere die Privatsphäre und persönlichen Grenzen anderer Nutzer. Konsens steht an oberster Stelle. Die Nutzung der App zur Verbreitung von Werbung, Spam oder für kommerzielle Zwecke ist untersagt."
      },
      {
        "title": "5. Verantwortung und Haftung",
        "content":
            "Wir übernehmen keine Verantwortung für Inhalte, die von Nutzern erstellt oder geteilt werden. Die Nutzung der App erfolgt auf eigenes Risiko. Für Schäden, die durch unsachgemäße Nutzung entstehen, übernehmen wir keine Haftung. Wir behalten uns vor, Nutzer bei Verstößen gegen diese Bedingungen vorübergehend oder dauerhaft von der Nutzung auszuschließen."
      },
      {
        "title": "6. Datenschutz",
        "content":
            "Alle Informationen zum Umgang mit personenbezogenen Daten findest du in unserer Datenschutzerklärung. Es werden keine sensiblen Daten an Dritte weitergegeben. Die App ist so konzipiert, dass deine Daten bestmöglich geschützt bleiben."
      },
      {
        "title": "7. Premium-Features",
        "content":
            "Premium-Inhalte oder -Funktionen können kostenpflichtig sein. Details zu Preisen, Inhalten und Kündigung findest du direkt im Bereich „Premium“ in der App. Es besteht kein Anspruch auf jederzeitige Verfügbarkeit einzelner Premium-Funktionen. Wir behalten uns vor, Angebote anzupassen oder einzustellen."
      },
      {
        "title": "8. Änderungen der Nutzungsbedingungen",
        "content":
            "Wir behalten uns vor, diese Nutzungsbedingungen jederzeit zu ändern. Änderungen werden in der App veröffentlicht. Durch die fortgesetzte Nutzung der App nach einer Änderung erklärst du dich mit den neuen Bedingungen einverstanden."
      },
      {
        "title": "9. Kontakt und Support",
        "content":
            "Bei Fragen, Problemen oder Feedback wende dich bitte über die Support- und Feedback-Funktion in der App oder per E-Mail an: [deine.email@domain.com]"
      },
      {
        "title": "10. Schlussbestimmungen",
        "content":
            "Sollten einzelne Bestimmungen dieser Nutzungsbedingungen unwirksam sein oder werden, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt. Es gilt das Recht der Bundesrepublik Deutschland."
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutzungsbedingungen'),
      ),
      body: SafeArea(
        child: Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: terms.length,
            itemBuilder: (context, index) {
              final term = terms[index];
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
                        term['title']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        term['content']!,
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
