import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pawpoints/Settings/schriftgroesse_screen.dart';
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
import 'package:provider/provider.dart';
import '../Settings/theme_provider.dart';

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
  final double statusBarHeight = MediaQuery.of(context).padding.top;

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
            // HEADER beginnt wirklich unter der Statusleiste
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: statusBarHeight,
                left: 24,
                right: 24,
                bottom: 18,
              ),
              color: favoriteColor,
              child: Stack(
                children: [
                  Column(
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
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) => IconButton(
                        icon: Icon(
                          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          themeProvider.toggleMode();
                        },
                        tooltip: themeProvider.isDarkMode
                            ? "Hellmodus aktivieren"
                            : "Dunkelmodus aktivieren",
                      ),
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
            // Inhalte und Actions mit Spacer ordentlich trennen!
            Expanded(
              child: Column(
                children: [
                  // HAUPTINHALT (ListView, ohne alles was unten sein soll)
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
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
                        ExpansionTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Einstellungen'),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.notifications_active),
                              title: const Text('Benachrichtigungen'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.beach_access),
                              title: const Text('Urlaubsmodus'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.language),
                              title: const Text('Sprache'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.format_size),
                              title: const Text('Schriftgröße'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SchriftgroesseScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        ExpansionTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Support'),
                          children: [
                            ListTile(
                              leading: const Icon(Icons.question_answer),
                              title: const Text('FAQ'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const FaqScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.feedback),
                              title: const Text('Support und Feedback'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const FeedbackOrSupportScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.article),
                              title: const Text('Nutzungsbedingungen'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const TermsOfUseScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip),
                              title: const Text('Datenschutz'),
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
                  // ALLES UNTERE IN EIGENER COLUMN UND MIT SPACER NACH UNTEN!
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.new_releases),
                    title: const Text('Was ist neu?'),
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
                    padding: const EdgeInsets.only(bottom: 18, left: 24, right: 24),
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
              ),
            ),
          ],
        );
      },
    ),
  );
}
