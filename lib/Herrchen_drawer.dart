import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pawpoints/Settings/herrchen_notification.dart';

import 'Settings/herrchen_profile_screen.dart';
import 'Settings/mydoggys_screen.dart';
import 'Settings/doggy_berechtigungen_screen.dart';
import 'Settings/herrchen_shop_screen.dart';
import 'Settings/premium_screen.dart';
import 'role_selection_screen.dart';
import 'roadmap_screen.dart';



Widget buildHerrchenDrawer(BuildContext context, VoidCallback refreshProfileImage, List<Map<String, dynamic>> doggys) {
  Future<Map<String, dynamic>?> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data();
  }

  return Drawer(
    child: Column(
      children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: loadUserData(),
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
                      Navigator.pop(context);
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
 children: [
   ListTile(
     leading: const Icon(Icons.notifications),
     title: const Text('Benachrichtigungen'),
     onTap: () {
       Navigator.of(context).pop(); // Drawer schließen
       Navigator.of(context).push(
         MaterialPageRoute(builder: (_) => const HerrchenNotifications()),
       );
     },
       ),
                  const ListTile(leading: Icon(Icons.calendar_month), title: Text('Wöchentliche Zusammenfassung')),
                  const ListTile(leading: Icon(Icons.card_giftcard), title: Text('Verlauf Belohnungen')),
                ],
              ),
              const ExpansionTile(
                leading: Icon(Icons.settings),
                title: Text('Einstellungen'),
                children: [
                  ListTile(leading: Icon(Icons.notifications_active), title: Text('Benachrichtigungen')),
                  ListTile(leading: Icon(Icons.lock), title: Text('Zugangs-PIN')),
                  ListTile(leading: Icon(Icons.palette), title: Text('Erscheinungsbild')),
                  ListTile(leading: Icon(Icons.visibility_off), title: Text('Diskreter Modus')),
                  ListTile(leading: Icon(Icons.beach_access), title: Text('Urlaubsmodus')),
                  ListTile(leading: Icon(Icons.language), title: Text('Sprache')),
                  ListTile(leading: Icon(Icons.format_size), title: Text('Schriftgröße')),
                  ListTile(leading: Icon(Icons.download), title: Text('Vorlage exportieren')),
                ],
              ),
              const ExpansionTile(
                leading: Icon(Icons.help_outline),
                title: Text('Support'),
                children: [
                  ListTile(leading: Icon(Icons.question_answer), title: Text('FAQ')),
                  ListTile(leading: Icon(Icons.feedback), title: Text('Support und Feedback')),
                  ListTile(leading: Icon(Icons.article), title: Text('Nutzungsbedingungen')),
                  ListTile(leading: Icon(Icons.privacy_tip), title: Text('Datenschutz')),
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
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                      (route) => false,
                );
              }
            }
          },
        ),

        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Version v.0.0.1 Alpha', style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}
