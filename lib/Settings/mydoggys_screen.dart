import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyDoggysScreen extends StatelessWidget {
  final List<Map<String, dynamic>> doggys;
  final String? inviteCode;

  const MyDoggysScreen({
    Key? key,
    required this.doggys,
    this.inviteCode,
  }) : super(key: key);

  /// Verschlüsselten Einladungscode aus UID generieren
  String _generateInviteCode(String uid) {
    final hash = sha256.convert(utf8.encode(uid));
    return hash.toString().substring(0, 10); // erste 10 Zeichen
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Du bist nicht eingeloggt')),
      );
    }

    final String code = inviteCode ?? _generateInviteCode(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Doggys'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: code,
              size: 200,
              version: QrVersions.auto,
            ),
            const SizedBox(height: 12),
            const Text(
              'Einladungscode:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            SelectableText(
              code,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Einladungscode kopiert')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Kopieren'),
            ),
            const SizedBox(height: 32),
            const Divider(),

            doggys.isEmpty
                ? Column(
                    children: const [
                      SizedBox(height: 32),
                      Icon(Icons.pets, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Noch keine Doggys verknüpft.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Teile deinen QR-Code oder Einladungscode,\num einen Doggy hinzuzufügen.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    children: doggys.map((doggy) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.pets),
                          title: Text(doggy['name'] ?? 'Unbenannter Doggy'),
                          subtitle: Text('Level: ${doggy['level'] ?? 1}'),
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 32),

            Opacity(
              opacity: 0.5,
              child: ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Streuner in der Umgebung finden'),
                subtitle: const Text('Premium-Inhalt – bald verfügbar'),
                trailing: const Icon(Icons.lock),
                onTap: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
