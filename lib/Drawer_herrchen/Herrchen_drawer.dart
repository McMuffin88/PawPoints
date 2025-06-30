import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '/Settings/herrchen_notification.dart';

import 'mydoggys_screen.dart';
import 'doggy_berechtigungen_screen.dart';
import 'herrchen_shop_screen.dart';
import '../Settings/premium_screen.dart';
import '../roadmap_screen.dart';
import '../main.dart';
import '/Start/changelog_screen.dart';
import '../faq_screen.dart';
import '../terms_of_use_screen.dart';
import '../privacy_policy_screen.dart';
import '../feedback_or_support_screen.dart';

final Map<String, Color> colorMap = {
  'Rot': Colors.red,
  'Blau': Colors.blue,
  'Grün': Colors.green,
  'Gelb': Colors.yellow,
  'Orange': Colors.orange,
  'Lila': Colors.purple,
  'Pink': Colors.pink,
  'Schwarz': Colors.black,
  'Weiß': Colors.white,
  'Grau': Colors.grey,
  'Braun': Colors.brown,
};

Widget buildHerrchenDrawer(BuildContext context, VoidCallback refreshProfileImage, List<Map<String, dynamic>> doggys) {
  return Drawer(
    child: FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String benutzername = data['benutzername'] ?? 'Herrchen';
        final String? imageUrl = data['profileImageUrl'];
        final String? favoriteColorName = data['favoriteColor'];
        final Color favoriteColor = (favoriteColorName != null && colorMap.containsKey(favoriteColorName))
            ? colorMap[favoriteColorName]!.withOpacity(0.55)
            : Colors.brown.withOpacity(0.55);

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 56, bottom: 18, left: 24, right: 24),
              color: favoriteColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (imageUrl != null && imageUrl.startsWith('http'))
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null
                        ? const Icon(Icons.account_circle, size: 48, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Willkommen',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    benutzername,
                    style: const TextStyle(
                      fontSize: 21,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ExpansionTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Konto'),
                    children: [
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
                          Navigator.of(context).pop();
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
ExpansionTile(
  leading: Icon(Icons.help_outline),
  title: Text('Support'),
  children: [
    ListTile(
      leading: Icon(Icons.question_answer),
      title: Text('FAQ'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const FaqScreen()),
        );
      },
    ),
ListTile(
  leading: Icon(Icons.feedback),
  title: Text('Support und Feedback'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FeedbackOrSupportScreen()),
    );
  },
),
ListTile(
  leading: Icon(Icons.article),
  title: Text('Nutzungsbedingungen'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TermsOfUseScreen()),
    );
  },
),
ListTile(
  leading: Icon(Icons.privacy_tip),
  title: Text('Datenschutz'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  },
),
  ],
),
                ],
              ),
            ),
                        ListTile(
  leading: Icon(Icons.new_releases),
  title: Text('Was ist neu?'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangelogScreen()),
    );
  },
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
                      MaterialPageRoute(builder: (_) => const PawPointsApp()),
                          (route) => false,
                    );
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '';
                  if (version.isEmpty) {
                    return const SizedBox();
                  }
                  return Text(
                    'Version $version',
                    style: const TextStyle(color: Colors.grey),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
