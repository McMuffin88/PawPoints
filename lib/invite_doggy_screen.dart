import 'dart:math';
import 'package:flutter/material.dart';
import 'herrchen_screen.dart';

class InviteDoggyScreen extends StatelessWidget {
  const InviteDoggyScreen({super.key});

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(8, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = _generateInviteCode();

    return Scaffold(
      appBar: AppBar(title: const Text('Doggy einladen')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Dein Einladungslink für den Doggy:',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SelectableText(
              inviteCode,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Dein Doggy gibt diesen Code später ein, um sich mit dir zu verbinden.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HerrchenScreen()),
                );
              },
              child: const Text('Fertig – Starte App'),
            ),
          ],
        ),
      ),
    );
  }
}
