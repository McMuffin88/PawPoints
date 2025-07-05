import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'doggy_drawer.dart';
import '../main.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../Start/bottom_navigator.dart';


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

  final _benutzernameController = TextEditingController();
  final _vornameController = TextEditingController();
  final _nachnameController = TextEditingController();
  final _plzController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _geburtsdatum;
  String? _selectedGender;
  String? _selectedFavoriteColor;
  String? _favoriteColorSaved; // <-- Wichtig für gespeicherte Buttonfarbe
  String? _profileImageUrl;

  bool _isEditing = false;
  bool _isLoading = false;

  // Diskret-Modus
  bool _diskretModus = false;
  String? _diskretPinHash;

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
    'Braun': Colors.brown,
  };

  Color get favoriteButtonColor =>
      (_favoriteColorSaved != null && _colorMap[_favoriteColorSaved!] != null)
          ? _colorMap[_favoriteColorSaved!]!
          : Colors.brown;

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore();
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

  Future<void> _loadProfileFromFirestore() async {
    setState(() {
      _isLoading = true;
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
        _benutzernameController.text = data['benutzername'] ?? '';
        _vornameController.text = data['vorname'] ?? '';
        _nachnameController.text = data['nachname'] ?? '';
        _plzController.text = data['plz'] ?? '';
        _cityController.text = data['city'] ?? '';

        if (data['geburtsdatum'] != null) {
          _geburtsdatum = (data['geburtsdatum'] as Timestamp).toDate();
        }
        _selectedGender = data['gender'];
        _selectedFavoriteColor = data['favoriteColor'];
        _favoriteColorSaved = data['favoriteColor']; // <--- für Button
        _profileImageUrl = data['profileImageUrl'];

        // Diskret-Modus laden
        _diskretModus = data['diskretModus'] ?? false;
        _diskretPinHash = data['pinHash']; // !!! geändert von 'diskretPinHash' zu 'pinHash'
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
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      setState(() {
        _isLoading = true;
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fehler: Benutzer nicht angemeldet.')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _profileImageUrl = downloadUrl;
        });

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

  Future<void> _selectDate(BuildContext context) async {
    if (!_isEditing) return;

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

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
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
        // Diskret-Modus wird separat im Switch gehandhabt
      });
      setState(() {
        _isEditing = false;
        _favoriteColorSaved = _selectedFavoriteColor; // <-- Jetzt erst übernehmen!
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
        _isLoading = false;
      });
    }
  }

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

        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        if (_profileImageUrl != null) {
          try {
            final storageRef = FirebaseStorage.instance.refFromURL(_profileImageUrl!);
            await storageRef.delete();
          } on FirebaseException catch (e) {
            print("Warnung: Konnte Profilbild nicht aus Storage löschen: ${e.code} - ${e.message}");
          } catch (e) {
            print("Warnung: Unerwarteter Fehler beim Löschen des Bildes aus Storage: $e");
          }
        }

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
            }
            return;
          } else {
            print("Firebase Auth Fehler beim Löschen des Benutzers: ${e.code} - ${e.message}");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fehler beim Löschen des Kontos: ${e.message}')),
              );
            }
            return;
          }
        } catch (e) {
          print("Allgemeiner Fehler beim Löschen des Authentifizierungs-Benutzers: $e");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unerwarteter Fehler beim Löschen des Kontos: ${e.toString()}')),
            );
          }
          return;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil erfolgreich gelöscht!')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PawPointsApp()),
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

  Future<void> _showPinChangeDialog() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN ändern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_diskretPinHash != null)
              TextField(
                controller: oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aktueller PIN',
                  hintText: 'Bitte alten PIN eingeben',
                ),
              ),
            if (_diskretPinHash != null)
              const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Neuer PIN',
                hintText: 'Mindestens 6 Ziffern',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Abbruch
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Der neue PIN muss mindestens 6 Ziffern lang sein.')),
                );
                return;
              }
              if (_diskretPinHash != null) {
                String oldHash = sha256.convert(utf8.encode(oldPinController.text)).toString();
                if (oldPinController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bitte den aktuellen PIN eingeben.')),
                  );
                  return;
                }
                if (oldHash != _diskretPinHash) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Der aktuelle PIN ist falsch!')),
                  );
                  return;
                }
              }
              String newHash = sha256.convert(utf8.encode(newPinController.text)).toString();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'pinHash': newHash,      // !!! geändert von 'diskretPinHash' zu 'pinHash'
                  'diskretModus': true,
                });
                setState(() {
                  _diskretPinHash = newHash;
                  _diskretModus = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN erfolgreich geändert!')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDisablePinDialog() async {
    final oldPinController = TextEditingController();
    bool ok = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diskret-Modus deaktivieren'),
        content: TextField(
          controller: oldPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN eingeben',
            hintText: 'Gib deinen aktuellen PIN ein',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Abbruch
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (oldPinController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bitte den aktuellen PIN eingeben!')),
                );
                return;
              }
              String hash = sha256.convert(utf8.encode(oldPinController.text)).toString();
              if (hash != _diskretPinHash) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN falsch!')),
                );
                return;
              }
              ok = true;
              Navigator.pop(context);
            },
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  iconTheme: const IconThemeData(color: Colors.white),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
  Navigator.pushReplacement(
  context, 
  MaterialPageRoute(builder: (_) => BottomNavigator(role: "doggy"))
      );
    },
  ),
),
      drawer: buildDoggyDrawer(context),
      body: _isLoading && !_isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: _profileImageUrl == null ? Colors.grey[300] : null,
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.startsWith('http')
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.camera_alt, size: 50, color: Colors.black54)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    keyboardType: TextInputType.number,
                    enabled: _isEditing,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
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
                  TextFormField(
                    readOnly: true,
                    enabled: _isEditing,
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
                    onChanged: _isEditing
                        ? (value) => setState(() {
                            _selectedFavoriteColor = value;
                          })
                        : null,
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
                  // DISKRET-MODUS SWITCH + PIN ändern ICON
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Diskret-Modus', style: TextStyle(color: Colors.white)),
                          value: _diskretModus,
                          onChanged: !_isEditing
                              ? null
                              : (val) async {
                                  if (!val) {
                                    // Nur beim Ausschalten: PIN-Abfrage!
                                    if (_diskretPinHash != null) {
                                      bool ok = await _showDisablePinDialog();
                                      if (ok) {
                                        setState(() {
                                          _diskretModus = false;
                                          _diskretPinHash = null;
                                        });
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                            'diskretModus': false,
                                            'pinHash': null,   // !!! geändert von 'diskretPinHash'
                                          });
                                        }
                                      }
                                      // Bei Abbruch bleibt der Switch AN!
                                    } else {
                                      // Wenn gar kein PIN gesetzt war, direkt ausschalten
                                      setState(() {
                                        _diskretModus = false;
                                      });
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                          'diskretModus': false,
                                          'pinHash': null,   // !!! geändert von 'diskretPinHash'
                                        });
                                      }
                                    }
                                  } else {
                                    // Beim Aktivieren des Diskret-Modus immer PIN festlegen!
                                    final TextEditingController newPinController = TextEditingController();
                                    final result = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('PIN festlegen'),
                                        content: TextField(
                                          controller: newPinController,
                                          obscureText: true,
                                          keyboardType: TextInputType.number,
                                          maxLength: 8,
                                          decoration: const InputDecoration(
                                            labelText: 'Neuer PIN',
                                            hintText: 'Mindestens 6 Ziffern',
                                            counterText: '',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Abbrechen'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              if (newPinController.text.length < 6) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Die PIN muss mindestens 6 Ziffern lang sein.')),
                                                );
                                                return;
                                              }
                                              Navigator.pop(context, true);
                                            },
                                            child: const Text('Festlegen'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (result == true && newPinController.text.length >= 6) {
                                      final String newHash = sha256.convert(utf8.encode(newPinController.text)).toString();
                                      setState(() {
                                        _diskretModus = true;
                                        _diskretPinHash = newHash;
                                      });
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                          'diskretModus': true,
                                          'pinHash': newHash,   // !!! geändert von 'diskretPinHash'
                                        });
                                      }
                                    }
                                  }
                                },
                        ),
                      ),
                      if (_diskretModus && _isEditing)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'PIN ändern',
                          onPressed: _showPinChangeDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Bearbeiten/Speichern/Abbrechen Button-Logik
                  if (!_isEditing)
                    ElevatedButton(
                      onPressed: () => setState(() => _isEditing = true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: favoriteButtonColor,
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Bearbeiten'),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: favoriteButtonColor,
                            minimumSize: const Size(120, 48),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Speichern'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                  _loadProfileFromFirestore(); // Reset Felder!
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 48),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          child: const Text('Abbrechen'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
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
