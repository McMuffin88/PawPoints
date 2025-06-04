// vollständiger HerrchenProfileScreen mit Menüpunkt „Konto“ statt Tabs
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _webImagePath;
  String _inviteCode = '';
  List<Map<String, dynamic>> _doggys = [];
  int _selectedView = 0; // 0: Profil, 1: Doggys, 2: Berechtigungen, 3: Premium

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('herrchen_name') ?? '';
    _emailController.text = prefs.getString('herrchen_email') ?? '';
    String? savedCode = prefs.getString('invite_code');
    if (savedCode == null) {
      savedCode = _generateInviteCode();
      await prefs.setString('invite_code', savedCode);
    }
    _inviteCode = savedCode;

    final imagePath = prefs.getString('herrchen_image');
    if (imagePath != null) {
      if (kIsWeb) {
        _webImagePath = imagePath;
      } else {
        final file = File(imagePath);
        if (await file.exists()) _profileImage = file;
      }
    }

    final doggyList = prefs.getString('doggys');
    if (doggyList == null) {
      _doggys = [
        {
          'name': 'Bello',
          'image': null,
          'berechtigungen': {
            'aufgabenHinzufuegen': true,
            'aufgabenBearbeiten': false,
            'regelnBearbeiten': false,
            'notizenBearbeiten': false,
            'historieBearbeiten': false
          }
        },
        {
          'name': 'Luna',
          'image': null,
          'berechtigungen': {
            'aufgabenHinzufuegen': true,
            'aufgabenBearbeiten': true,
            'regelnBearbeiten': true,
            'notizenBearbeiten': true,
            'historieBearbeiten': true
          }
        },
      ];
      await prefs.setString('doggys', jsonEncode(_doggys));
    } else {
      _doggys = List<Map<String, dynamic>>.from(jsonDecode(doggyList));
    }

    setState(() {});
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) => chars[(now + i) % chars.length]).join();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      _webImagePath = pickedFile.path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('herrchen_image', _webImagePath!);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      _profileImage = savedImage;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('herrchen_image', savedImage.path);
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('herrchen_name', _nameController.text);
    await prefs.setString('herrchen_email', _emailController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil gespeichert')),
    );
  }

  Future<void> _saveDoggyPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doggys', jsonEncode(_doggys));
  }

  Future<void> _removeDoggy(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _doggys.removeAt(index));
    await prefs.setString('doggys', jsonEncode(_doggys));
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungscode kopiert')),
    );
  }

  Widget _buildDoggyList() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        final name = doggy['name'] ?? 'Doggy';
        final imagePath = doggy['image'];
        Widget avatar = const CircleAvatar(child: Icon(Icons.pets));
        if (imagePath != null) {
          if (kIsWeb) {
            avatar = CircleAvatar(backgroundImage: NetworkImage(imagePath));
          } else if (File(imagePath).existsSync()) {
            avatar = CircleAvatar(backgroundImage: FileImage(File(imagePath)));
          }
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

  Widget _buildPermissionsTab() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        final name = doggy['name'] ?? 'Doggy';
        final image = doggy['image'];
        final permissions = Map<String, dynamic>.from(doggy['berechtigungen'] ?? {});
        Widget avatar = const CircleAvatar(child: Icon(Icons.pets));
        if (image != null) {
          if (kIsWeb) {
            avatar = CircleAvatar(backgroundImage: NetworkImage(image));
          } else if (File(image).existsSync()) {
            avatar = CircleAvatar(backgroundImage: FileImage(File(image)));
          }
        }

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [avatar, const SizedBox(width: 12), Text(name, style: const TextStyle(fontSize: 18))]),
                ...[
                  {'key': 'aufgabenHinzufuegen', 'label': 'Aufgaben, Belohnungen und Strafen hinzufügen'},
                  {'key': 'aufgabenBearbeiten', 'label': 'Aufgaben, Belohnungen und Strafen bearbeiten/löschen'},
                  {'key': 'regelnBearbeiten', 'label': 'Regeln bearbeiten'},
                  {'key': 'notizenBearbeiten', 'label': 'Notizen bearbeiten'},
                  {'key': 'historieBearbeiten', 'label': 'Aufgabenhistorie bearbeiten'},
                ].map((perm) => SwitchListTile(
                      title: Text(perm['label']!),
                      value: permissions[perm['key']] ?? false,
                      onChanged: (val) {
                        setState(() => _doggys[index]['berechtigungen'][perm['key']] = val);
                        _saveDoggyPermissions();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (kIsWeb && _webImagePath != null) {
      imageProvider = NetworkImage(_webImagePath!);
    } else if (_profileImage != null) {
      imageProvider = FileImage(_profileImage!);
    }

    Widget bodyContent;
    switch (_selectedView) {
      case 0:
        bodyContent = SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: imageProvider,
                  child: imageProvider == null ? const Icon(Icons.add_a_photo, size: 40) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _saveProfile, child: const Text('Speichern')),
            ],
          ),
        );
        break;
      case 1:
        bodyContent = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: _buildDoggyList()),
              const SizedBox(height: 16),
              Text('Einladungscode: $_inviteCode', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _copyInviteCode,
                icon: const Icon(Icons.copy),
                label: const Text('In Zwischenablage kopieren'),
              ),
            ],
          ),
        );
        break;
      case 2:
        bodyContent = _buildPermissionsTab();
        break;
      case 3:
        bodyContent = const Center(child: Text('Premium-Funktionen folgen bald...'));
        break;
      default:
        bodyContent = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herrchen-Profil'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu),
            onSelected: (index) => setState(() => _selectedView = index),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Profil')),
              const PopupMenuItem(value: 1, child: Text('Meine Doggys')),
              const PopupMenuItem(value: 2, child: Text('Berechtigungen')),
              const PopupMenuItem(value: 3, child: Text('Premium')),
            ],
          ),
        ],
      ),
      body: bodyContent,
    );
  }
}
