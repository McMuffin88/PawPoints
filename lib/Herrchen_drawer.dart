import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'herrchen_profile_screen.dart';
import 'meine_doggys_screen.dart';
import 'doggy_berechtigungen_screen.dart';
import 'herrchen_shop_screen.dart';

Widget buildHerrchenDrawer(BuildContext context, VoidCallback refreshProfileImage) {
  Future<ImageProvider?> _getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('herrchen_image');
    if (imagePath != null) {
      if (kIsWeb) {
        return NetworkImage(imagePath);
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          return FileImage(file);
        }
      }
    }
    return null;
  }

  return Drawer(
    child: Column(
      children: [
        FutureBuilder<ImageProvider?>(
          future: _getProfileImage(),
          builder: (context, snapshot) {
            final image = snapshot.connectionState == ConnectionState.done && snapshot.hasData
                ? snapshot.data
                : null;
            return UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.brown),
              accountName: const Text("Mein Konto"),
              accountEmail: const Text(""),
              currentAccountPicture: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: image,
                child: image == null ? const Icon(Icons.person, size: 40, color: Colors.brown) : null,
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
                      refreshProfileImage(); // <- aktualisiert Drawer-Bild
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('Meine Doggys'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MeineDoggysScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield),
                    title: const Text('Berechtigungen'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DoggyBerechtigungenScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.store),
                    title: const Text('Shop'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HerrchenShopScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: const Text('Premium'),
                    onTap: () {},
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
