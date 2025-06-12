import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Settings/herrchen_profile_screen.dart';
import 'Settings/mydoggys_screen.dart';
import 'Settings/doggy_berechtigungen_screen.dart';
import 'Settings/herrchen_shop_screen.dart';
import 'Settings/premium_screen.dart';

Widget buildHerrchenDrawer(BuildContext context, VoidCallback refreshProfileImage, List<Map<String, dynamic>> doggys) {
  Future<Map<String, dynamic>?> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data();
  }

  return Drawer(
    child: Column(
      children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: _loadUserData(),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final name = data?['name'] ?? 'Herrchen';
            final imageUrl = data?['profileImageUrl'];

            return UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.brown),
              accountName: Text(name),
              accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: (imageUrl != null && imageUrl.toString().startsWith('http'))
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.brown)
                    : null,
              ),
            );
          },
        ),
        Expanded(
          child: ListView(
            children: [
              ExpansionTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Konto'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profil anpassen'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HerrchenProfileScreen()),
                      );
                      refreshProfileImage();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Meine Doggys'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MyDoggysScreen(doggys: doggys)),
                      );
                    },
                  ),
ListTile(
  leading: const Icon(Icons.shield),
  title: const Text('Berechtigungen'),
  onTap: () {
    Navigator.pop(context); // Drawer schließen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DoggyBerechtigungenScreen()),
    );
  },
),

                  ListTile(
                    leading: const Icon(Icons.store),
                    title: const Text('Shop'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HerrchenShopScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: const Text('Premium'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Tätigkeiten'),
                children: const [
                  ListTile(
                    leading: Icon(Icons.notifications),
                    title: Text('Benachrichtigungen'),
                  ),
                  ListTile(
                    leading: Icon(Icons.calendar_month),
                    title: Text('Wöchentliche Zusammenfassung'),
                  ),
                  ListTile(
                    leading: Icon(Icons.card_giftcard),
                    title: Text('Verlauf Belohnungen'),
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.settings),
                title: const Text('Einstellungen'),
                children: const [
                  ListTile(
                    leading: Icon(Icons.notifications_active),
                    title: Text('Benachrichtigungen'),
                  ),
                  ListTile(
                    leading: Icon(Icons.lock),
                    title: Text('Zugangs-PIN'),
                  ),
                  ListTile(
                    leading: Icon(Icons.palette),
                    title: Text('Erscheinungsbild'),
                  ),
                  ListTile(
                    leading: Icon(Icons.visibility_off),
                    title: Text('Diskreter Modus'),
                  ),
                  ListTile(
                    leading: Icon(Icons.beach_access),
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
                    leading: Icon(Icons.download),
                    title: Text('Vorlage exportieren'),
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Support'),
                children: const [
                  ListTile(
                    leading: Icon(Icons.question_answer),
                    title: Text('FAQ'),
                  ),
                  ListTile(
                    leading: Icon(Icons.feedback),
                    title: Text('Support und Feedback'),
                  ),
                  ListTile(
                    leading: Icon(Icons.article),
                    title: Text('Nutzungsbedingungen'),
                  ),
                  ListTile(
                    leading: Icon(Icons.privacy_tip),
                    title: Text('Datenschutz'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Version v.0.0.1 Alpha', style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}
