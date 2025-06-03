import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HerrchenProfileScreen extends StatefulWidget {
  const HerrchenProfileScreen({super.key});

  @override
  State<HerrchenProfileScreen> createState() => _HerrchenProfileScreenState();
}

class _HerrchenProfileScreenState extends State<HerrchenProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  File? _profileImage;
  String? _webImagePath; // für Web

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('herrchen_displayname') ?? '';
    _emailController.text = prefs.getString('herrchen_email') ?? '';

    final imagePath = prefs.getString('herrchen_image');
    if (imagePath != null) {
      if (kIsWeb) {
        setState(() {
          _webImagePath = imagePath;
        });
      } else if (File(imagePath).existsSync()) {
        setState(() {
          _profileImage = File(imagePath);
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      await prefs.setString('herrchen_image', pickedFile.path);
      setState(() {
        _webImagePath = pickedFile.path;
      });
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      await prefs.setString('herrchen_image', savedImage.path);
      setState(() {
        _profileImage = savedImage;
      });
    }
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('herrchen_displayname', _nameController.text);
    await prefs.setString('herrchen_email', _emailController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil gespeichert')),
    );
  }

  Widget _buildProfileImage() {
    if (kIsWeb && _webImagePath != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(_webImagePath!),
      );
    } else if (_profileImage != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: FileImage(_profileImage!),
      );
    } else {
      return const CircleAvatar(
        radius: 60,
        child: Icon(Icons.add_a_photo, size: 40),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Herrchen-Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: _buildProfileImage(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-Mail'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
