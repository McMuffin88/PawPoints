import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'doggy_profile_screen.dart';
import 'doggy_shop_screen.dart';
import 'package:pawpoints/Drawer_Doggy/find_herrchen_screen.dart';
import '../roadmap_screen.dart';
import '../main.dart'; // Import main.dart

Widget buildDoggyDrawer(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return const Drawer(
      child: Center(child: Text('Nicht eingeloggt')),
    );
  }

  return Drawer(
    child: FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
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
            Text(
              doggyName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ExpansionTile(
                    leading: const Icon(Icons.account_box),
                    title: const Text('Konto'),
                    children: [
                      // Der "Profil anzeigen" Link wurde entfernt,
                      // da das Profil jetzt über die Bottom-Navigation zugänglich ist.
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Herrchen finden'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FindHerrchenScreen(),
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
                        leading: const Icon(Icons.shop),
                        title: const Text('Shop'),
                        onTap: () {
                          Navigator.pop(context); // erst Drawer schließen
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DoggyShopScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const ExpansionTile(
                    leading: Icon(Icons.settings),
                    title: Text('Einstellungen'),
                    children: [
                      ListTile(leading: Icon(Icons.notifications), title: Text('Benachrichtigungen')),
                      ListTile(leading: Icon(Icons.lock), title: Text('Zugangs-PIN')),
                      ListTile(leading: Icon(Icons.color_lens), title: Text('Erscheinungsbild')),
                      ListTile(leading: Icon(Icons.visibility_off), title: Text('Diskreter Modus')),
                      ListTile(leading: Icon(Icons.flight), title: Text('Urlaubsmodus')),
                      ListTile(leading: Icon(Icons.language), title: Text('Sprache')),
                      ListTile(leading: Icon(Icons.format_size), title: Text('Schriftgröße')),
                      ListTile(leading: Icon(Icons.upload_file), title: Text('Vorlage exportieren')),
                    ],
                  ),
                  const ExpansionTile(
                    leading: Icon(Icons.support),
                    title: Text('Support'),
                    children: [
                      ListTile(leading: Icon(Icons.help), title: Text('FAQ')),
                      ListTile(leading: Icon(Icons.feedback), title: Text('Feedback')),
                      ListTile(leading: Icon(Icons.privacy_tip), title: Text('Datenschutz')),
                      ListTile(leading: Icon(Icons.article), title: Text('Nutzungsbedingungen')),
                    ],
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Roadmap'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoadmapScreen()),
                );
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Abmelden?'),
                    content: const Text('Möchtest du dich wirklich abmelden?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Abbrechen'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const PawPointsApp ()), // Changed to Mainscreen
                          (route) => false,
                    );
                  }
                }
              },
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Version 0.0.1 Alpha',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    ),
  );
}
