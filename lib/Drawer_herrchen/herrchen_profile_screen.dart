import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'herrchen_drawer.dart';
import '../main.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

InputDecoration customFieldDecoration(
    String label,
    bool isEditing, {
    String? hintText,
    Widget? suffixIcon,
}) {
    final radius = BorderRadius.all(Radius.circular(isEditing ? 0 : 20));

    return InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: const Color(0xFF29272C),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
                color: isEditing ? Colors.grey : Colors.transparent,
                width: isEditing ? 1.5 : 0,
            ),
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
                color: isEditing ? Colors.transparent : Colors.transparent,
                width: isEditing ? 1.5 : 0,
            ),
        ),
        disabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        suffixIcon: suffixIcon,
    );
}

class HerrchenProfileScreen extends StatefulWidget {
    const HerrchenProfileScreen({super.key});

    @override
    State<HerrchenProfileScreen> createState() => _HerrchenProfileScreenState();
}

class _HerrchenProfileScreenState extends State<HerrchenProfileScreen> {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    final _benutzernameController = TextEditingController();
    final _vornameController = TextEditingController();
    final _nachnameController = TextEditingController();
    final _plzController = TextEditingController();
    final _cityController = TextEditingController();

    DateTime? _geburtsdatum;
    String? _selectedGender;
    String? _selectedFavoriteColor;
    String? _favoriteColorSaved; // <- für gespeicherte Buttonfarbe
    String? _profileImageUrl;

    bool _isEditing = false;
    bool _isLoading = false;

    // Diskret-Modus:
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
        setState(() => _isLoading = true);
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
            setState(() => _isLoading = false);
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
                _favoriteColorSaved = data['favoriteColor'];
                _profileImageUrl = data['profileImageUrl'];

                // Diskret-Modus laden
                _diskretModus = data['diskretModus'] ?? false;
                _diskretPinHash = data['pinHash']; // <--- geändert
            }
        } catch (e) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fehler beim Laden des Profils: $e')),
                );
            }
        } finally {
            setState(() => _isLoading = false);
        }
    }

    Future<void> _pickImage() async {
        final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
        if (pickedFile != null) {
            File imageFile = File(pickedFile.path);
            setState(() => _isLoading = true);
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
                final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
                await storageRef.putFile(imageFile);
                final downloadUrl = await storageRef.getDownloadURL();
                setState(() { _profileImageUrl = downloadUrl; });
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'profileImageUrl': downloadUrl,
                });
                if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profilbild erfolgreich hochgeladen!')),
                    );
                }
            } catch (e) {
                if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim Hochladen: $e')),
                    );
                }
            } finally {
                setState(() { _isLoading = false; });
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
            setState(() { _geburtsdatum = picked; });
        }
    }

    Future<void> _saveProfile() async {
        setState(() { _isLoading = true; });
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
            setState(() { _isLoading = false; });
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
            });
            setState(() {
                _isEditing = false;
                _favoriteColorSaved = _selectedFavoriteColor; // <-- Buttonfarbe erst nach Speichern übernehmen!
            });
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil erfolgreich gespeichert!')),
                );
            }
        } catch (e) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fehler beim Speichern: $e')),
                );
            }
        } finally {
            setState(() { _isLoading = false; });
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
            setState(() { _isLoading = true; });
            try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

                if (_profileImageUrl != null) {
                    try {
                        final storageRef = FirebaseStorage.instance.refFromURL(_profileImageUrl!);
                        await storageRef.delete();
                    } catch (e) {
                        print("Warnung: Konnte Profilbild nicht aus Storage löschen: $e");
                    }
                }

                try {
                    await user.delete();
                } catch (e) {
                    if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fehler beim Löschen des Kontos: $e')),
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
            } catch (e) {
                if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim Löschen des Profils: $e')),
                    );
                }
            } finally {
                setState(() { _isLoading = false; });
            }
        }
    }

    // ---------- DISKRET-MODUS-Logik analog Doggy ----------
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
                        onPressed: () => Navigator.pop(context),
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
                                    'pinHash': newHash, // geändert
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
                        onPressed: () => Navigator.pop(context),
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
            extendBodyBehindAppBar: true,
            appBar: AppBar(
                title: const Text('Profil bearbeiten (Herrchen)', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
            ),
            drawer: buildHerrchenDrawer(context, () {}, []),
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

                            // Benutzername
                            TextFormField(
                                controller: _benutzernameController,
                                decoration: customFieldDecoration(
                                    'Benutzername',
                                    _isEditing,
                                    hintText: 'Gib deinen gewünschten Benutzernamen ein',
                                ),
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

                            // Vorname
                            TextFormField(
                                controller: _vornameController,
                                decoration: customFieldDecoration(
                                    'Vorname',
                                    _isEditing,
                                    hintText: 'Gib deinen Vornamen ein',
                                ),
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

                            // Nachname
                            TextFormField(
                                controller: _nachnameController,
                                decoration: customFieldDecoration(
                                    'Nachname',
                                    _isEditing,
                                    hintText: 'Gib deinen Nachnamen ein',
                                ),
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

                            // PLZ
                            TextFormField(
                                controller: _plzController,
                                decoration: customFieldDecoration(
                                    'Postleitzahl',
                                    _isEditing,
                                    hintText: 'Gib deine Postleitzahl ein',
                                ),
                                keyboardType: TextInputType.number,
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

                            // Stadt
                            TextFormField(
                                controller: _cityController,
                                decoration: customFieldDecoration(
                                    'Stadt',
                                    _isEditing,
                                    hintText: 'In welcher Stadt wohnst du?',
                                ),
                                enabled: _isEditing,
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

                            // Geburtsdatum
                            TextFormField(
                                readOnly: true,
                                enabled: _isEditing,
                                controller: TextEditingController(
                                    text: _geburtsdatum == null
                                        ? ''
                                        : DateFormat('dd.MM.yyyy').format(_geburtsdatum!),
                                ),
                                onTap: _isEditing ? () => _selectDate(context) : null,
                                decoration: customFieldDecoration(
                                    'Geburtsdatum',
                                    _isEditing,
                                    hintText: 'Geburtsdatum auswählen',
                                    suffixIcon: _isEditing
                                        ? const Icon(Icons.calendar_today, color: Colors.brown)
                                        : null,
                                ),
                                style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),

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
                                                                        'pinHash': null, // geändert
                                                                    });
                                                                }
                                                            }
                                                        } else {
                                                            setState(() { _diskretModus = false; });
                                                            final user = FirebaseAuth.instance.currentUser;
                                                            if (user != null) {
                                                                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                                                    'diskretModus': false,
                                                                    'pinHash': null, // geändert
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
                                                                    'pinHash': newHash, // geändert
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
                                                    _loadProfileFromFirestore();
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
