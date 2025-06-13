import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../doggy_drawer.dart';

class DoggyProfileScreen extends StatefulWidget {
  const DoggyProfileScreen({super.key});

  @override
  State<DoggyProfileScreen> createState() => _DoggyProfileScreenState();
}

class _DoggyProfileScreenState extends State<DoggyProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dogNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  String _gender = '';
  String? _profileImageUrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore();
  }

  Future<void> _loadProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;

    _firstNameController.text = data['firstName'] ?? '';
    _lastNameController.text = data['lastName'] ?? '';
    _dogNameController.text = data['name'] ?? '';
    _ageController.text = data['age'] ?? '';
    _cityController.text = data['city'] ?? '';
    _gender = data['gender'] ?? '';
    _profileImageUrl = data['profileImageUrl'];
    setState(() {});
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'name': _dogNameController.text,
      'age': _ageController.text,
      'city': _cityController.text,
      'gender': _gender,
      'profileImageUrl': _profileImageUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil gespeichert')),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = await ref.putData(await pickedFile.readAsBytes());
    final downloadUrl = await ref.getDownloadURL();

    setState(() => _profileImageUrl = downloadUrl);
  }

  Future<void> _deleteProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil löschen'),
        content: const Text('Möchtest du dein Profil wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil gelöscht')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_profileImageUrl!);
    }

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: buildDoggyDrawer(context),
      appBar: AppBar(
        title: const Text('Doggy-Profil'),
        actions: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: imageProvider,
                child: imageProvider == null ? const Icon(Icons.person) : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickAndUploadImage : null,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: imageProvider,
                child: imageProvider == null ? const Icon(Icons.add_a_photo, size: 40) : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Vorname'), enabled: _isEditing),
            const SizedBox(height: 12),
            TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Nachname'), enabled: _isEditing),
            const SizedBox(height: 12),
            TextField(controller: _dogNameController, decoration: const InputDecoration(labelText: 'Rufname'), enabled: _isEditing),
            const SizedBox(height: 12),
            TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Alter'), enabled: _isEditing),
            const SizedBox(height: 12),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Stadt'), enabled: _isEditing),
            const SizedBox(height: 12),
DropdownButtonFormField<String>(
  value: ['männlich', 'weiblich', 'divers'].contains(_gender) ? _gender : null,
  items: const [
    DropdownMenuItem(value: 'männlich', child: Text('Männlich')),
    DropdownMenuItem(value: 'weiblich', child: Text('Weiblich')),
    DropdownMenuItem(value: 'divers', child: Text('Divers')),
  ],
  onChanged: _isEditing ? (val) => setState(() => _gender = val ?? '') : null,
  decoration: const InputDecoration(labelText: 'Geschlecht'),
),


            const SizedBox(height: 24),
            _isEditing
                ? ElevatedButton(onPressed: () async { await _saveProfile(); setState(() => _isEditing = false); }, child: const Text('Speichern'))
                : OutlinedButton(onPressed: () => setState(() => _isEditing = true), child: const Text('Bearbeiten')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _deleteProfile,
              child: const Text('Profil löschen', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}
