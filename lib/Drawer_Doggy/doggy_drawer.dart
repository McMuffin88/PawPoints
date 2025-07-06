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
import 'package:provider/provider.dart';
import '../Settings/theme_provider.dart';
import '../Settings/schriftgroesse_screen.dart';
import '../Settings/premium_screen.dart';

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
  return _DoggyDrawer();
}

class _DoggyDrawer extends StatefulWidget {
  @override
  State<_DoggyDrawer> createState() => _DoggyDrawerState();
}

class _DoggyDrawerState extends State<_DoggyDrawer> {
  int _expandedIndex = -1; // -1 = nichts offen

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Drawer(
        child: Center(child: Text('Nicht eingeloggt')),
      );
    }

    final double statusBarHeight = MediaQuery.of(context).padding.top;

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
              // Header – mit Abstand zur Statusleiste
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
              // Menü & unterer Bereich
Expanded(
  child: Column(
    children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ExpansionTile(
              key: Key('tile_0_${_expandedIndex == 0}'),
              leading: Icon(Icons.account_box, color: _expandedIndex == 0 ? favoriteColor : Colors.white),
              title: const Text('Konto'),
              trailing: Icon(
                _expandedIndex == 0 ? Icons.expand_less : Icons.expand_more,
                color: _expandedIndex == 0 ? favoriteColor : Colors.white54,
              ),
              initiallyExpanded: _expandedIndex == 0,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? 0 : -1;
                });
              },
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
              key: Key('tile_1_${_expandedIndex == 1}'),
              leading: Icon(Icons.shopping_bag, color: _expandedIndex == 1 ? favoriteColor : Colors.white),
              title: const Text('Tätigkeiten'),
              trailing: Icon(
                _expandedIndex == 1 ? Icons.expand_less : Icons.expand_more,
                color: _expandedIndex == 1 ? favoriteColor : Colors.white54,
              ),
              initiallyExpanded: _expandedIndex == 1,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? 1 : -1;
                });
              },
              children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('PawPass'),
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
              key: Key('tile_2_${_expandedIndex == 2}'),
              leading: Icon(Icons.settings, color: _expandedIndex == 2 ? favoriteColor : Colors.white),
              title: const Text('Einstellungen'),
              trailing: Icon(
                _expandedIndex == 2 ? Icons.expand_less : Icons.expand_more,
                color: _expandedIndex == 2 ? favoriteColor : Colors.white54,
              ),
              initiallyExpanded: _expandedIndex == 2,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? 2 : -1;
                });
              },
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
              key: Key('tile_3_${_expandedIndex == 3}'),
              leading: Icon(Icons.help_outline, color: _expandedIndex == 3 ? favoriteColor : Colors.white),
              title: const Text('Support'),
              trailing: Icon(
                _expandedIndex == 3 ? Icons.expand_less : Icons.expand_more,
                color: _expandedIndex == 3 ? favoriteColor : Colors.white54,
              ),
              initiallyExpanded: _expandedIndex == 3,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? 3 : -1;
                });
              },
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
  ),
),

            ],
          );
        },
      ),
    );
  }
}
