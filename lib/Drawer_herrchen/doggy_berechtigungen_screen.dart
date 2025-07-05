import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'mydoggys_screen.dart';
import '../Settings/premium_screen.dart';

final Map<String, Color> colorMap = {
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

class DoggyBerechtigungenScreen extends StatefulWidget {
  const DoggyBerechtigungenScreen({Key? key}) : super(key: key);

  @override
  _DoggyBerechtigungenScreenState createState() => _DoggyBerechtigungenScreenState();
}

class _DoggyBerechtigungenScreenState extends State<DoggyBerechtigungenScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  Map<String, Map<String, dynamic>> _permissionsCache = {};
  bool _isSaving = false;
  bool _isPremium = false;
  Color _favoriteColor = Colors.brown; // Standardwert

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _loadFavoriteColor();
  }

  Future<void> _checkPremium() async {
    try {
      final result = await _functions.httpsCallable('checkHerrchenPremiumStatus').call();
      setState(() {
        _isPremium = result.data['isPremium'] ?? false;
      });
    } catch (e) {
      print('Fehler beim Prüfen des Premium-Status: $e');
    }
  }

  Future<void> _loadFavoriteColor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = doc.data()?['favoriteColor'];
    if (name != null && colorMap.containsKey(name)) {
      setState(() {
        _favoriteColor = colorMap[name]!;
      });
    }
  }

  Future<String> _loadInviteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['inviteCode'] ?? '';
  }

  Future<void> _loadAllPermissions(List<String> doggyIds, String herrchenId) async {
    if (doggyIds.isEmpty) return;
    try {
      final res = await _functions.httpsCallable('getAllHerrchenPermissions').call({
        'doggyIds': doggyIds,
      });

      final Map<String, dynamic> rawData = Map<String, dynamic>.from(res.data['permissions'] ?? {});
      setState(() {
        _permissionsCache = rawData.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
      });
    } catch (e) {
      print('Fehler beim Laden der Berechtigungen: $e');
    }
  }

  Future<void> _updatePermission(String doggyId, String herrchenId, String fieldName, bool value) async {
    setState(() => _isSaving = true);

    try {
      await _functions.httpsCallable('updateDoggyPermissions').call({
        'doggyId': doggyId,
        'permissions': {fieldName: value},
      });
      setState(() {
        _permissionsCache[doggyId] = (_permissionsCache[doggyId] ?? {})..[fieldName] = value;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Aktualisieren der Berechtigung')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildNoDoggysView(BuildContext context, String inviteCode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Du bist aktuell mit keinem Doggy verbunden.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bitte verwende deinen Einladungs- oder QR-Code, um die Verbindung herzustellen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyDoggysScreen(inviteCode: inviteCode),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Zu Meine Doggys'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String doggyId, String herrchenId, String fieldName, String label,
      {bool premium = false}) {
    bool currentValue = _permissionsCache[doggyId]?[fieldName] ?? false;
    bool isDisabled = premium && !_isPremium;

    return SwitchListTile(
      title: Text(label),
      subtitle: isDisabled ? const Text('Nur mit Premium verfügbar') : null,
      value: currentValue,
      onChanged: isDisabled
          ? (_) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            }
          : (val) => _updatePermission(doggyId, herrchenId, fieldName, val),
      activeColor: isDisabled ? Colors.grey : _favoriteColor,
    );
  }

  Widget _buildDoggyList(QuerySnapshot snapshot, String herrchenId) {
    final doggys = snapshot.docs;
    if (doggys.isEmpty) return const SizedBox.shrink();

    final doggyIds = doggys.map((d) => d.id).toList();

    if (_permissionsCache.length != doggyIds.length) {
      _loadAllPermissions(doggyIds, herrchenId);
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: doggys.length,
      itemBuilder: (context, index) {
        final doc = doggys[index];
        final doggyId = doc.id;
        final data = doc.data() as Map<String, dynamic>;
        final permissions = _permissionsCache[doggyId] ?? {};

        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: data['profileImageUrl'] != null
                        ? NetworkImage(data['profileImageUrl'])
                        : null,
                    child: data['profileImageUrl'] == null ? const Icon(Icons.pets) : null,
                  ),
                  title: Text(data['benutzername'] ?? 'Unbenannt'),
                  subtitle: Text('Status: ${permissions['status'] ?? 'aktiv'}'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Text(
                    _isPremium ? 'Berechtigungen' : 'Basis-Berechtigungen',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildSwitch(doggyId, herrchenId, 'canCompleteTasks', 'Darf Aufgaben selbst abschließen'),
                _buildSwitch(doggyId, herrchenId, 'canSendMessages', 'Darf Nachrichten an Herrchen schicken'),

                if (!_isPremium) ...[
                  const Divider(height: 32),
Text(
  'Premium-Bereich (Upgrade nötig)',
  style: TextStyle(
    fontWeight: FontWeight.bold,
    color: _favoriteColor,
  ),
),
                ],

_buildSwitch(
  doggyId,
  herrchenId,
  'canReactToPunishment',
  'Darf Bestrafungen kommentieren',
  premium: true,
),
_buildSwitch(
  doggyId,
  herrchenId,
  'canJoinChallenges',
  'Darf an wöchentlichen Herausforderungen teilnehmen',
  premium: true,
),
_buildSwitch(
  doggyId,
  herrchenId,
  'canSuggestRewards',
  'Darf neue Belohnungen vorschlagen',
  premium: true,
),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nicht eingeloggt')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Berechtigungen')),
      body: FutureBuilder<String>(
        future: _loadInviteCode(),
        builder: (context, inviteSnapshot) {
          if (!inviteSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final inviteCode = inviteSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('doggys')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return _buildNoDoggysView(context, inviteCode);
              }

              return _buildDoggyList(snapshot.data!, user.uid);
            },
          );
        },
      ),
      bottomNavigationBar: _isSaving
          ? Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Änderung wird gespeichert...', style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : null,
    );
  }
}
