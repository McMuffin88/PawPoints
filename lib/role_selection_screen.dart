import 'package:flutter/material.dart';
import 'doggy_screen.dart';
import 'herrchen_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PawPoints')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Wer bist du?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Ich bin das Herrchen'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HerrchenScreen()));
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.pets),
              label: const Text('Ich bin der Doggy'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DoggyScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
