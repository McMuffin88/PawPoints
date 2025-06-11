import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../herrchen_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedGender;
  XFile? _pickedImage;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("Nicht eingeloggt");

        String? imageUrl;

        if (_pickedImage != null) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user.uid}.jpg');

          if (kIsWeb) {
            final bytes = await _pickedImage!.readAsBytes();
            await ref.putData(bytes);
          } else {
            final file = io.File(_pickedImage!.path);
            await ref.putFile(file);
          }

          final imageUrl = await ref.getDownloadURL(); // ✅ DAS ist die richtige URL
        }

// Und jetzt funktioniert das hier:
await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'name': _nameController.text.trim(),
  'age': _ageController.text.trim(),
  'gender': _selectedGender,
  'city': _cityController.text.trim(),
  'profileImageUrl': imageUrl, // ✅ wird korrekt übernommen
  'email': user.email,
  'role': 'herrchen',
  'uid': user.uid,
});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HerrchenScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: ${e.toString()}')),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildProfileImage() {
    if (_pickedImage == null) {
      return const Icon(Icons.add_a_photo, size: 40);
    }

    if (kIsWeb) {
      return ClipOval(
        child: Image.network(
          _pickedImage!.path,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return ClipOval(
        child: Image.file(
          io.File(_pickedImage!.path),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil erstellen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  child: _buildProfileImage(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Alter (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'm', child: Text('Männlich')),
                  DropdownMenuItem(value: 'w', child: Text('Weiblich')),
                  DropdownMenuItem(value: 'd', child: Text('Divers')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
                decoration: const InputDecoration(labelText: 'Geschlecht'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Wohnort (optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Profil speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
