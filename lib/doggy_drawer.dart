import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'Settings/doggy_profile_screen.dart';
import 'doggy_shop_screen.dart';

Widget buildDoggyDrawer(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;

  return Drawer(
    child: FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final doggyName = data['name'] ?? 'Doggy';
        final imageUrl = data['profileImageUrl'] as String?;

        return Column(
          children: [
            const SizedBox(height: 40),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: imageUrl != null && imageUrl.startsWith('http')
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl == null
                    ? const Icon(Icons.account_circle, size: 60)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(doggyName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ExpansionTile(
                    leading: const Icon(Icons.account_box),
                    title: const Text('Konto'),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Profil anzeigen'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DoggyProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: const Text('Tätigkeiten'),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.card_giftcard),
                        title: const Text('Shop'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoggyShopScreen(doggyName: doggyName),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Einstellungen'),
                    children: const [
                      ListTile(
                        leading: Icon(Icons.notifications),
                        title: Text('Benachrichtigungen'),
                      ),
                      ListTile(
                        leading: Icon(Icons.lock),
                        title: Text('Zugangs-PIN'),
                      ),
                      ListTile(
                        leading: Icon(Icons.color_lens),
                        title: Text('Erscheinungsbild'),
                      ),
                      ListTile(
                        leading: Icon(Icons.visibility_off),
                        title: Text('Diskreter Modus'),
                      ),
                      ListTile(
                        leading: Icon(Icons.flight),
                        title: Text('Urlaubsmodus'),
                      ),
                      ListTile(
                        leading: Icon(Icons.language),
                        title: Text('Sprache'),
                      ),
                      ListTile(
                        leading: Icon(Icons.format_size),
                        title: Text('Schriftgröße'),
                      ),
                      ListTile(
                        leading: Icon(Icons.upload_file),
                        title: Text('Vorlage exportieren'),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.support),
                    title: const Text('Support'),
                    children: const [
                      ListTile(
                        leading: Icon(Icons.help),
                        title: Text('FAQ'),
                      ),
                      ListTile(
                        leading: Icon(Icons.feedback),
                        title: Text('Feedback'),
                      ),
                      ListTile(
                        leading: Icon(Icons.privacy_tip),
                        title: Text('Datenschutz'),
                      ),
                      ListTile(
                        leading: Icon(Icons.article),
                        title: Text('Nutzungsbedingungen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Version 0.0.1 Alpha',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    ),
  );
}
