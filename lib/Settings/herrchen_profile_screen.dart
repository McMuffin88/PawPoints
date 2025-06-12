import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'mydoggys_screen.dart';
import 'premium_screen.dart';
import 'herrchen_shop_screen.dart';
import '../herrchen_drawer.dart';

class HerrchenProfileScreen extends StatefulWidget {
  const HerrchenProfileScreen({super.key});

  @override
  State<HerrchenProfileScreen> createState() => _HerrchenProfileScreenState();
}

class _HerrchenProfileScreenState extends State<HerrchenProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  String _gender = '';
  String? _profileImageUrl;
  bool _isEditing = false;
  List<Map<String, dynamic>> _doggys = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;

    setState(() {
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _ageController.text = data['age'] ?? '';
      _cityController.text = data['city'] ?? '';
      _gender = data['gender'] ?? '';
      _profileImageUrl = data['profileImageUrl'];
    });

    final doggySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('doggys')
        .get();

    setState(() {
      _doggys = doggySnapshot.docs.map((e) => e.data()).cast<Map<String, dynamic>>().toList();
    });
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

    await ref.putFile(File(pickedFile.path));
    final url = await ref.getDownloadURL();

    setState(() => _profileImageUrl = url);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'profileImageUrl': url,
    });
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
      await FirebaseAuth.instance.signOut();

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildProfileForm() {
    ImageProvider? imageProvider;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_profileImageUrl!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickAndUploadImage : null,
            child: CircleAvatar(
              radius: 60,
              backgroundImage: imageProvider,
              child: imageProvider == null ? const Icon(Icons.person, size: 40) : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name'), enabled: _isEditing),
          const SizedBox(height: 12),
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-Mail'), enabled: _isEditing),
          const SizedBox(height: 12),
          TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Alter'), enabled: _isEditing),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Stadt'), enabled: _isEditing),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _gender.isNotEmpty ? _gender : null,
            items: const [
              DropdownMenuItem(value: 'm', child: Text('Männlich')),
              DropdownMenuItem(value: 'w', child: Text('Weiblich')),
              DropdownMenuItem(value: 'd', child: Text('Divers')),
            ],
            onChanged: _isEditing ? (val) => setState(() => _gender = val ?? '') : null,
            decoration: const InputDecoration(labelText: 'Geschlecht'),
          ),
          const SizedBox(height: 24),
          _isEditing
              ? ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                        'name': _nameController.text,
                        'email': _emailController.text,
                        'age': _ageController.text,
                        'city': _cityController.text,
                        'gender': _gender,
                      });
                    }
                    setState(() => _isEditing = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil gespeichert')));
                  },
                  child: const Text('Speichern'),
                )
              : OutlinedButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Bearbeiten'),
                ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _deleteProfile,
            child: const Text('Profil löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildProfileForm();
      case 1:
        return MyDoggysScreen(doggys: _doggys);
      case 2:
        return const Center(child: Text('Berechtigungen folgen...'));
      case 3:
        return const HerrchenShopScreen();
      case 4:
        return const PremiumScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: buildHerrchenDrawer(context, _loadUserData, _doggys),
      appBar: AppBar(
        title: const Text('Herrchen-Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profil'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Doggys'),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Berechtigungen'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'Premium'),
        ],
      ),
    );
  }
}