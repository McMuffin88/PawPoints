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
import '../Settings/AdminPanelScreen.dart';

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
            // HEADER
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
            Expanded(
              child: HerrchenDrawerContent(
                doggys: doggys,
                favoriteColor: favoriteColor,
                data: data,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class HerrchenDrawerContent extends StatefulWidget {
  final List<Map<String, dynamic>> doggys;
  final Color favoriteColor;
  final Map<String, dynamic> data;

  const HerrchenDrawerContent({
    super.key,
    required this.doggys,
    required this.favoriteColor,
    required this.data,
  });

  @override
  State<HerrchenDrawerContent> createState() => _HerrchenDrawerContentState();
}

class _HerrchenDrawerContentState extends State<HerrchenDrawerContent> {
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // KORREKTUR: Die unteren Elemente sind nun außerhalb der ListView, um einen festen Footer zu erzeugen.
    return Column(
      children: [
        // OBERER, SCROLLBARER TEIL
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ExpansionTile(
                key: Key('tile_0_${_expandedIndex == 0}'),
                leading: Icon(Icons.account_circle, color: _expandedIndex == 0 ? widget.favoriteColor : Colors.white),
                title: const Text('Konto'),
                trailing: Icon(
                  _expandedIndex == 0 ? Icons.expand_less : Icons.expand_more,
                  color: _expandedIndex == 0 ? widget.favoriteColor : Colors.white54,
                ),
                initiallyExpanded: _expandedIndex == 0,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedIndex = expanded ? 0 : -1;
                  });
                },
                children: [
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Meine Doggys'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MyDoggysScreen(doggys: widget.doggys)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield),
                    title: const Text('Berechtigungen'),
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.doggys.isNotEmpty) {
                        final firstDoggyId = widget.doggys[0]['id'] ?? widget.doggys[0]['doggyId'];
                        if (firstDoggyId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DoggyBerechtigungenScreen()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kein Doggy ausgewählt')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Keine Doggys vorhanden')),
                        );
                      }
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
                key: Key('tile_1_${_expandedIndex == 1}'),
                leading: Icon(Icons.check_circle_outline, color: _expandedIndex == 1 ? widget.favoriteColor : Colors.white),
                title: const Text('Tätigkeiten'),
                trailing: Icon(
                  _expandedIndex == 1 ? Icons.expand_less : Icons.expand_more,
                  color: _expandedIndex == 1 ? widget.favoriteColor : Colors.white54,
                ),
                initiallyExpanded: _expandedIndex == 1,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedIndex = expanded ? 1 : -1;
                  });
                },
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
                key: Key('tile_2_${_expandedIndex == 2}'),
                leading: Icon(Icons.settings, color: _expandedIndex == 2 ? widget.favoriteColor : Colors.white),
                title: const Text('Einstellungen'),
                trailing: Icon(
                  _expandedIndex == 2 ? Icons.expand_less : Icons.expand_more,
                  color: _expandedIndex == 2 ? widget.favoriteColor : Colors.white54,
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
                leading: Icon(Icons.help_outline, color: _expandedIndex == 3 ? widget.favoriteColor : Colors.white),
                title: const Text('Support'),
                trailing: Icon(
                  _expandedIndex == 3 ? Icons.expand_less : Icons.expand_more,
                  color: _expandedIndex == 3 ? widget.favoriteColor : Colors.white54,
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
        // UNTERER, FESTER TEIL (FOOTER)
        if ((widget.data['roles'] as List?)?.contains('admin') == true)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
            title: const Text('Adminpanel'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
            },
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
          padding: const EdgeInsets.only(bottom: 18, left: 24, right: 24, top: 8),
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
  }
}