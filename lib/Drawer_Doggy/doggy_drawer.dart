import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'doggy_shop_screen.dart';
import '/Drawer_Doggy/find_herrchen_screen.dart';
import '../roadmap_screen.dart';
import '../main.dart';
import '/Start/changelog_screen.dart';
import '../faq_screen.dart';
import '../privacy_policy_screen.dart';
import '../terms_of_use_screen.dart';
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
        final String benutzername = data['benutzername'] ?? 'Doggy';
        final String? imageUrl = data['profileImageUrl'] as String?;
        final String? favoriteColorName = data['favoriteColor'];
        final Color favoriteColor =
            (favoriteColorName != null && colorMap[favoriteColorName] != null)
                ? colorMap[favoriteColorName]!.withOpacity(0.55)
                : Colors.brown.withOpacity(0.55);

        return Column(
          children: [
            // Header: alles linksbündig, Border unten
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
                    backgroundImage: imageUrl != null && imageUrl.startsWith('http')
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
            // Weißer, halbtransparenter Border als Trennlinie unter dem Header
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white
            ),
            const SizedBox(height: 8),

            // Drawer-Menü
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ExpansionTile(
                    leading: const Icon(Icons.account_box),
                    title: const Text('Konto'),
                    children: [
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
                          Navigator.pop(context);
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
            // Dynamische Version
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
