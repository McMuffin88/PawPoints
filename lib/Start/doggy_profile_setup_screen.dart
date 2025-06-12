// DoggyProfileSetupScreen.dart – mit Bild-Upload, E-Mail Pflicht und initState-Fix
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class DoggyProfileSetupScreen extends StatefulWidget {
  final bool withoutHerrchen;
  final String? invitationCode;

  const DoggyProfileSetupScreen({
    super.key,
    required this.withoutHerrchen,
    this.invitationCode,
  });

  @override
  State<DoggyProfileSetupScreen> createState() => _DoggyProfileSetupScreenState();
}

class _DoggyProfileSetupScreenState extends State<DoggyProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dogNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _cityController = TextEditingController();
  String? _linkedHerrchenUid;
  String? _profileImageUrl;
  File? _profileImage;
  bool _checkingCode = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte zuerst anmelden und E-Mail bestätigen.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    if (!widget.withoutHerrchen && widget.invitationCode != null) {
      _verifyInvitationCode(widget.invitationCode!);
    }
  }

  Future<void> _verifyInvitationCode(String code) async {
    setState(() => _checkingCode = true);
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final herrchenDoc = query.docs.first;
      _linkedHerrchenUid = herrchenDoc.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Herrchen gefunden: ${herrchenDoc['name']}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einladungscode ungültig.')),
      );
    }
    setState(() => _checkingCode = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler: Kein eingeloggter Nutzer.')),
      );
      return;
    }

    final fileName = 'profile_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);

    UploadTask uploadTask;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      _profileImage = File(pickedFile.path);
      uploadTask = ref.putFile(_profileImage!);
    }

    await uploadTask;
    final url = await ref.getDownloadURL();
    setState(() => _profileImageUrl = url);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doggyData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'name': _dogNameController.text.trim(),
      'age': _ageController.text.trim(),
      'gender': _genderController.text.trim(),
      'city': _cityController.text.trim(),
      'email': user.email,
      'role': 'doggy',
      'linkedTo': _linkedHerrchenUid,
      'profileImageUrl': _profileImageUrl,
    };

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(doggyData);

    if (_linkedHerrchenUid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_linkedHerrchenUid)
          .collection('doggys')
          .doc(user.uid)
          .set({
        'name': _dogNameController.text.trim(),
        'uid': user.uid,
        'image': _profileImageUrl,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil gespeichert!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_profileImageUrl!);
    } else if (_profileImage != null) {
      imageProvider = FileImage(_profileImage!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Doggy Profil anlegen')),
      body: _checkingCode
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: imageProvider,
                          child: imageProvider == null
                              ? const Icon(Icons.add_a_photo, size: 40)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'Vorname (nicht sichtbar)'),
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Vornamen eingeben' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Nachname (nicht sichtbar)'),
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Nachnamen eingeben' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dogNameController,
                      decoration: const InputDecoration(labelText: 'Rufname (sichtbar)'),
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Hundenamen eingeben' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: 'Alter'),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Alter eingeben' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _genderController.text.isNotEmpty ? _genderController.text : null,
                      items: const [
                        DropdownMenuItem(value: 'männlich', child: Text('Männlich')),
                        DropdownMenuItem(value: 'weiblich', child: Text('Weiblich')),
                        DropdownMenuItem(value: 'divers', child: Text('Divers')),
                      ],
                      decoration: const InputDecoration(labelText: 'Geschlecht'),
                      onChanged: (val) => setState(() => _genderController.text = val ?? ''),
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Geschlecht wählen' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Stadt'),
                      validator: (val) => val == null || val.isEmpty ? 'Bitte Stadt angeben' : null,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Profil anlegen'),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}