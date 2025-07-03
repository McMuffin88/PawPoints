import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'schriftgroesse_provider.dart';

class SchriftgroesseScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var schriftProvider = Provider.of<SchriftgroesseProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Schriftgröße einstellen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Allgemeine Schriftgröße: ${schriftProvider.allgemeineSchriftgroesse.toInt()}',
              style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse),
            ),
            Slider(
              value: schriftProvider.allgemeineSchriftgroesse,
              min: 10,
              max: 30,
              divisions: 20,
              onChanged: (v) => schriftProvider.setAllgemeineSchriftgroesse(v),
            ),
            SizedBox(height: 24),
            Text(
              'Button-Schriftgröße: ${schriftProvider.buttonSchriftgroesse.toInt()}',
              style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse),
            ),
            Slider(
              value: schriftProvider.buttonSchriftgroesse,
              min: 10,
              max: 30,
              divisions: 20,
              onChanged: (v) => schriftProvider.setButtonSchriftgroesse(v),
            ),
            const SizedBox(height: 32),
            Divider(),
            Text(
              'Live-Vorschau:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: schriftProvider.allgemeineSchriftgroesse,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Das ist ein Beispieltext, der sich sofort mit der allgemeinen Schriftgröße anpasst.',
              style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text(
                'Button mit dynamischer Schrift',
                style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {},
              child: Text(
                'Noch ein Button',
                style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {},
              child: Text(
                'TextButton Beispiel',
                style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Zurück"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Speichern"),
                    onPressed: () {
                      // Optional: Snackbar als Feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Schriftgrößen wurden gespeichert.')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
