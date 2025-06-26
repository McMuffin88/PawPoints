// lib/Drawer_Doggy/doggy_profile_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Für File
import 'package:intl/intl.dart'; // Für DateFormat (pubspec.yaml: intl: ^0.18.1)

import 'doggy_drawer.dart'; // Sicherstellen, dass dieser Import korrekt ist
import '../main.dart'; // Import für PawPointsApp (zum Navigieren nach Logout/Löschen)


// Am besten oben bei den anderen Imports
InputDecoration customFieldDecoration(
  String label,
  bool isEditing, {
  String? hintText,
  Widget? suffixIcon,
}) {
  final borderRadius = BorderRadius.all(Radius.circular(isEditing ? 0 : 20));
  final borderColor = isEditing ? Colors.grey : Colors.transparent;
  final borderWidth = isEditing ? 1.5 : 0.0;

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: const TextStyle(color: Colors.white),
    hintStyle: const TextStyle(color: Colors.white),
    filled: true,
    fillColor: const Color(0xFF29272C),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: isEditing ? Colors.brown : Colors.transparent,
        width: borderWidth,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: Colors.transparent, width: 0),
    ),
    suffixIcon: suffixIcon,
  );
}



class DoggyProfileScreen extends StatefulWidget {
  const DoggyProfileScreen({super.key});

  @override
  State<DoggyProfileScreen> createState() => _DoggyProfileScreenState();
}

class _DoggyProfileScreenState extends State<DoggyProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Text-Controller für die Felder, die 1:1 aus main.dart übernommen werden
  final _benutzernameController = TextEditingController();
  final _vornameController = TextEditingController();
  final _nachnameController = TextEditingController();
  final _plzController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _geburtsdatum;
  String? _selectedGender;
  String? _selectedFavoriteColor; // Feld für die Lieblingsfarbe
  String? _profileImageUrl; // URL des Profilbildes

  bool _isEditing = false; // Steuert, ob die Felder editierbar sind
  bool _isLoading = false; // Ladezustand für Speichern/Laden

  // Map von Farbnamen zu tatsächlichen Color-Objekten für die Anzeige
  final Map<String, Color> _colorMap = {
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
    'Braun': Colors.brown, // Häufige Farbe, die auch vorkommen könnte
  };

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore(); // Profil beim Initialisieren laden
  }

  @override
  void dispose() {
    _benutzernameController.dispose();
    _vornameController.dispose();
    _nachnameController.dispose();
    _plzController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Lädt die Profilinformationen aus Firestore, basierend auf main.dart-Feldern.
  Future<void> _loadProfileFromFirestore() async {
    setState(() {
      _isLoading = true; // Ladezustand aktivieren
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data != null) {
        // Daten aus Firestore in die Controller und Variablen laden
        _benutzernameController.text = data['benutzername'] ?? '';
        _vornameController.text = data['vorname'] ?? '';
        _nachnameController.text = data['nachname'] ?? '';
        _plzController.text = data['plz'] ?? '';
        _cityController.text = data['city'] ?? '';

        if (data['geburtsdatum'] != null) {
          _geburtsdatum = (data['geburtsdatum'] as Timestamp).toDate();
        }
        _selectedGender = data['gender'];
        _selectedFavoriteColor = data['favoriteColor']; // Lieblingsfarbe laden
        _profileImageUrl = data['profileImageUrl'];
      }
    } on FirebaseException catch (e) {
      print("Firebase Firestore Fehler beim Laden des Profils: ${e.code} - ${e.message}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden des Profils: ${e.message}')),
        );
      }
    } catch (e) {
      print("Allgemeiner Fehler beim Laden des Profils: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unerwarteter Fehler beim Laden des Profils: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // Ladezustand deaktivieren
      });
    }
  }

  /// Wählt ein Bild aus der Galerie und lädt es in Firebase Storage hoch.
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70); // Reduzierte Qualität

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      setState(() {
        _isLoading = true; // Ladezustand aktivieren
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fehler: Benutzer nicht angemeldet.')),
            );
          }
          setState(() { _isLoading = false; });
          return;
        }

        // Korrekter Pfad für Profilbilder im Storage (verwenden wir die UID des Benutzers)
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');

        // Hochladen der Datei
        await storageRef.putFile(imageFile);

        // Download-URL abrufen
        final downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _profileImageUrl = downloadUrl; // Lokalen State aktualisieren
        });

        // URL in Firestore aktualisieren
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImageUrl': downloadUrl,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profilbild erfolgreich hochgeladen!')),
          );
        }
      } on FirebaseException catch (e) {
        print("Firebase Storage Fehler beim Hochladen: ${e.code} - ${e.message}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Hochladen des Bildes: ${e.message}')),
          );
        }
      } catch (e) {
        print("Allgemeiner Fehler beim Hochladen des Bildes: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unerwarteter Fehler beim Hochladen: ${e.toString()}')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Wählt ein Geburtsdatum über einen DatePicker aus.
  Future<void> _selectDate(BuildContext context) async {
    if (!_isEditing) return; // Nur im Bearbeitungsmodus erlauben

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _geburtsdatum ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _geburtsdatum) {
      setState(() {
        _geburtsdatum = picked;
      });
    }
  }

  /// Speichert die aktualisierten Profilinformationen in Firestore.
  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true; // Ladezustand aktivieren
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'benutzername': _benutzernameController.text.trim(),
        'vorname': _vornameController.text.trim(),
        'nachname': _nachnameController.text.trim(),
        'plz': _plzController.text.trim(),
        'city': _cityController.text.trim(),
        'geburtsdatum': _geburtsdatum != null ? Timestamp.fromDate(_geburtsdatum!) : null,
        'gender': _selectedGender,
        'favoriteColor': _selectedFavoriteColor,
        // 'profileImageUrl' wird bereits in _pickImage() separat aktualisiert
      });
      setState(() {
        _isEditing = false; // Bearbeitungsmodus beenden
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil erfolgreich gespeichert!')),
        );
      }
    } on FirebaseException catch (e) {
      print("Firebase Firestore Fehler beim Speichern: ${e.code} - ${e.message}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: ${e.message}')),
        );
      }
    } catch (e) {
      print("Allgemeiner Fehler beim Speichern des Profils: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unerwarteter Fehler beim Speichern: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // Ladezustand deaktivieren
      });
    }
  }

  /// Löscht das Benutzerprofil (Dokument) aus Firestore und das zugehörige Profilbild aus Storage.
  /// Dies löscht das gesamte Benutzerprofil, da es keine separate "Doggy"-Entität gibt.
  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil löschen?'),
        content: const Text('Möchtest du dein gesamtes Profil wirklich löschen? Dies kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Firestore-Dokument löschen
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        // Optional: Profilbild aus Storage löschen
        if (_profileImageUrl != null) {
          try {
            final storageRef = FirebaseStorage.instance.refFromURL(_profileImageUrl!);
            await storageRef.delete();
          } on FirebaseException catch (e) {
            print("Warnung: Konnte Profilbild nicht aus Storage löschen: ${e.code} - ${e.message}");
            // Hier werfen wir keinen Fehler, da das Hauptziel (Profil in Firestore löschen) erreicht wurde.
          } catch (e) {
            print("Warnung: Unerwarteter Fehler beim Löschen des Bildes aus Storage: $e");
          }
        }

        // Benutzer aus der Authentifizierung löschen (sehr wichtig nach dem Löschen der Daten)
        // Dies ist eine kritische Operation und erfordert oft ein erneutes Anmelden des Benutzers,
        // bevor sie ausgeführt werden kann, um Sicherheitsrisiken zu vermeiden.
        // Wenn der Nutzer nicht kürzlich angemeldet war, kann dies fehlschlagen.
        try {
          await user.delete();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            print("Fehler beim Löschen des Authentifizierungs-Benutzers: ${e.code} - ${e.message}");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Bitte melden Sie sich erneut an, um Ihr Konto zu löschen. Sicherheitshinweis.')),
              );
              // Wenn dieser Fehler auftritt, sollte der Benutzer zur erneuten Anmeldung aufgefordert werden.
              // Danach kann die Löschfunktion erneut versucht werden.
            }
            return; // Abbrechen, da der Auth-Teil fehlgeschlagen ist
          } else {
            print("Firebase Auth Fehler beim Löschen des Benutzers: ${e.code} - ${e.message}");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fehler beim Löschen des Kontos: ${e.message}')),
              );
            }
            return; // Abbrechen bei anderen Auth-Fehlern
          }
        } catch (e) {
          print("Allgemeiner Fehler beim Löschen des Authentifizierungs-Benutzers: $e");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unerwarteter Fehler beim Löschen des Kontos: ${e.toString()}')),
            );
          }
          return; // Abbrechen bei anderen Fehlern
        }


        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil erfolgreich gelöscht!')),
          );
          // Nach dem Löschen zur Startseite (PawPointsApp in main.dart) navigieren
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PawPointsApp()), // Navigiere zum Root-Widget (Deine Haupt-App)
            (route) => false,
          );
        }
      } on FirebaseException catch (e) {
        print("Firebase Firestore Fehler beim Löschen des Profils: ${e.code} - ${e.message}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Löschen des Profils: ${e.message}')),
          );
        }
      } catch (e) {
        print("Allgemeiner Fehler beim Löschen des Profils: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unerwarteter Fehler beim Löschen: ${e.toString()}')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Profil bearbeiten (Doggy)'),
        backgroundColor: Colors.brown,
        actions: [
          if (!_isEditing) // Wenn nicht im Bearbeitungsmodus, zeige Bearbeiten-Button
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing) // Wenn im Bearbeitungsmodus, zeige Speichern-Button (mit Ladeanzeige)
            IconButton(
              icon: _isLoading // Zeige Ladekreis, wenn gespeichert wird
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveProfile, // Button deaktivieren, wenn geladen wird
            ),
        ],
      ),
      drawer: buildDoggyDrawer(context), // Doggy Drawer verwenden
      body: _isLoading && !_isEditing // Zeige zentralen Ladekreis nur beim initialen Laden
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null, // Profilbild nur im Bearbeitungsmodus klickbar
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: _profileImageUrl == null ? Colors.grey[300] : null, // Set color only if no image
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.startsWith('http')
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.camera_alt, size: 50, color: Colors.black54)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Benutzername (entspricht _benutzernameController in main.dart)
                  TextFormField(
                    controller: _benutzernameController,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      hintText: 'Gib deinen gewünschten Benutzernamen ein',
                      labelStyle: TextStyle(color: Color.fromARGB(255, 155, 154, 154)),
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                    ),
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // Vorname (entspricht _vornameController in main.dart)
                  TextFormField(
                    controller: _vornameController,
                    decoration: const InputDecoration(
                      labelText: 'Vorname',
                      hintText: 'Gib deinen Vornamen ein',
                      labelStyle: TextStyle(color: Color.fromARGB(255, 155, 154, 154)),
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                    ),
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // Nachname (entspricht _nachnameController in main.dart)
                  TextFormField(
                    controller: _nachnameController,
                    decoration: const InputDecoration(
                      labelText: 'Nachname',
                      hintText: 'Gib deinen Nachnamen ein',
                      labelStyle: TextStyle(color: Color.fromARGB(255, 155, 154, 154)),
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                    ),
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // PLZ (entspricht _plzController in main.dart)
                  TextFormField(
                    controller: _plzController,
                    decoration: const InputDecoration(
                      labelText: 'Postleitzahl',
                      hintText: 'Gib deine Postleitzahl ein',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                    ),
                    keyboardType: TextInputType.number, // PLZ ist numerisch
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // Stadt (entspricht _cityController in main.dart)
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Stadt',
                      hintText: 'In welcher Stadt wohnst du?',
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                    ),
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),

                  // Geburtsdatum (entspricht _geburtsdatum in main.dart)
TextFormField(
  readOnly: true,
  enabled: _isEditing, // Nur im Bearbeitungsmodus aktiv
  controller: TextEditingController(
    text: _geburtsdatum == null
      ? ''
      : DateFormat('dd.MM.yyyy').format(_geburtsdatum!),
  ),
  onTap: _isEditing ? () => _selectDate(context) : null,
  decoration: InputDecoration(
    labelText: 'Geburtsdatum',
    hintText: 'Geburtsdatum auswählen',
    labelStyle: const TextStyle(color: Colors.white),
    hintStyle: const TextStyle(color: Colors.white70),
    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
    suffixIcon: _isEditing
        ? const Icon(Icons.calendar_today, color: Colors.brown)
        : null,
  ),
  style: const TextStyle(color: Colors.white),
),
const SizedBox(height: 12),

                  // Geschlecht (entspricht _selectedGender in main.dart)

// Geschlecht
DropdownButtonFormField<String>(
  value: ['männlich', 'weiblich', 'divers'].contains(_selectedGender) ? _selectedGender : null,
  items: const [
    DropdownMenuItem(value: 'männlich', child: Text('Männlich', style: TextStyle(color: Colors.white))),
    DropdownMenuItem(value: 'weiblich', child: Text('Weiblich', style: TextStyle(color: Colors.white))),
    DropdownMenuItem(value: 'divers', child: Text('Divers', style: TextStyle(color: Colors.white))),
  ],
  onChanged: _isEditing ? (val) => setState(() => _selectedGender = val) : null,
  decoration: customFieldDecoration(
    'Geschlecht',
    _isEditing,
    hintText: 'Wähle dein Geschlecht',
  ),
  hint: const Text('Wähle dein Geschlecht', style: TextStyle(color: Colors.white)),
  style: const TextStyle(color: Colors.white),
  dropdownColor: Colors.black,
),
const SizedBox(height: 12),

// Lieblingsfarbe
DropdownButtonFormField<String>(
  value: _selectedFavoriteColor,
  items: _colorMap.keys.map((colorName) {
    return DropdownMenuItem(
      value: colorName,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _colorMap[colorName] ?? Colors.transparent,
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Text(colorName, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }).toList(),
  onChanged: _isEditing ? (value) => setState(() => _selectedFavoriteColor = value) : null,
  decoration: customFieldDecoration(
    'Lieblingsfarbe',
    _isEditing,
    hintText: 'Wähle deine Lieblingsfarbe',
    suffixIcon: _selectedFavoriteColor != null && _colorMap[_selectedFavoriteColor!] != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _colorMap[_selectedFavoriteColor!],
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          )
        : null,
  ),
  hint: const Text('Wähle deine Lieblingsfarbe', style: TextStyle(color: Colors.white)),
  style: const TextStyle(color: Colors.white),
  dropdownColor: Colors.black,
),

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _deleteProfile,
                    child: const Text('Profil löschen', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
    );
  }
}