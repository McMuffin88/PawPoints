import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

class _HerrchenProfileScreenState extends State<HerrchenProfileScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  File? _profileImage;
  String? _webImagePath;
  String _inviteCode = '';
  List<Map<String, dynamic>> _doggys = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('herrchen_name') ?? '';
    _emailController.text = prefs.getString('herrchen_email') ?? '';
setState(() {
  _inviteCode = prefs.getString('invite_code') ?? 'wird beim Setup generiert';
});


    final imagePath = prefs.getString('herrchen_image');
    if (imagePath != null) {
      if (kIsWeb) {
        setState(() => _webImagePath = imagePath);
      } else if (File(imagePath).existsSync()) {
        setState(() => _profileImage = File(imagePath));
      }
    }

    final doggyList = prefs.getString('doggys');
    if (doggyList != null) {
      setState(() {
        _doggys = List<Map<String, dynamic>>.from(jsonDecode(doggyList));
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(pickedFile.path);
    final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('herrchen_image', savedImage.path);

    setState(() {
      _profileImage = savedImage;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('herrchen_name', _nameController.text);
    await prefs.setString('herrchen_email', _emailController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil gespeichert')),
    );
  }

  Future<void> _removeDoggy(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _doggys.removeAt(index));
    await prefs.setString('doggys', jsonEncode(_doggys));
  }

  Widget _buildDoggyList() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        final name = doggy['name'] ?? 'Doggy';
        final imagePath = doggy['image'];
        Widget avatar;

        if (imagePath != null) {
          if (kIsWeb) {
            avatar = CircleAvatar(backgroundImage: NetworkImage(imagePath));
          } else if (File(imagePath).existsSync()) {
            avatar = CircleAvatar(backgroundImage: FileImage(File(imagePath)));
          } else {
            avatar = const CircleAvatar(child: Icon(Icons.pets));
          }
        } else {
          avatar = const CircleAvatar(child: Icon(Icons.pets));
        }

        return ListTile(
          leading: avatar,
          title: Text(name),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeDoggy(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Herrchen-Profil'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.person), text: 'Profil'),
              Tab(icon: Icon(Icons.pets), text: 'Meine Doggys'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.add_a_photo, size: 40)
                          : null,
                    ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Einladungscode: $_inviteCode', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Expanded(child: _buildDoggyList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
