import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';


class MyDoggysScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? doggys;
  final String? inviteCode;

  const MyDoggysScreen({super.key, this.doggys, this.inviteCode});

  @override
  State<MyDoggysScreen> createState() => _MyDoggysScreenState();
}

class _MyDoggysScreenState extends State<MyDoggysScreen> {
  List<Map<String, dynamic>> _doggys = [];
  List<QueryDocumentSnapshot> _pendingRequests = [];
  bool _isLoading = true;

  // Einladungscode-Logik
  String? _einladungscode;
  DateTime? _codeErstelltAm;
  bool _isCodeLoading = true;

  @override
  void initState() {
    super.initState();
    _doggys = widget.doggys ?? [];
    _loadData();
    _fetchInviteCode(); // NEU: Einladungscode holen/generieren
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doggysSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('doggys')
        .get();

    final pending = await FirebaseFirestore.instance
        .collection('invites')
        .where('herrchenId', isEqualTo: user.uid)
        .where('doggyConfirmed', isEqualTo: true)
        .where('used', isEqualTo: false)
        .get();

    final doggys = doggysSnap.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList().cast<Map<String, dynamic>>();

    for (final doc in doggysSnap.docs) {
      final doggyId = doc.id;
      final assignedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(doggyId)
          .collection('assignedHerrchen')
          .doc(user.uid);
      final assignedDoc = await assignedRef.get();
      if (!assignedDoc.exists) {
        final herrchenDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final herrchenData = herrchenDoc.data();
        await assignedRef.set({
          'name': herrchenData?['name'] ?? 'Herrchen',
          'status': 'aktiv',
          'connectedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    setState(() {
      _doggys = doggys;
      _pendingRequests = pending.docs;
      _isLoading = false;
    });
  }

  // NEU: Einladungscode aus Cloud Function holen!
  Future<void> _fetchInviteCode() async {
    setState(() => _isCodeLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkOrCreateInviteCode');
      final result = await callable.call();
      final data = result.data;
      setState(() {
        _einladungscode = data['code'];
        if (data['erstelltAm'] != null) {
          // Firestore Timestamp zu Dart DateTime
          _codeErstelltAm = (data['erstelltAm']['_seconds'] != null)
              ? DateTime.fromMillisecondsSinceEpoch(data['erstelltAm']['_seconds'] * 1000)
              : null;
        }
        _isCodeLoading = false;
      });
    } catch (e) {
      setState(() {
        _einladungscode = null;
        _isCodeLoading = false;
      });
      debugPrint("Fehler beim Holen des Einladungscodes: $e");
    }
  }

  // --- Der Rest deiner Funktionen bleibt erhalten (keine Einladungscode-Generierung mehr nötig!) ---

  Future<void> _acceptInvite(String inviteId, String doggyId) async {
    final herrchenId = FirebaseAuth.instance.currentUser!.uid;
    final doggyDoc = await FirebaseFirestore.instance.collection('users').doc(doggyId).get();

    if (!doggyDoc.exists) return;
    final doggyData = doggyDoc.data()!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Doggy akzeptieren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: doggyData['profileImageUrl'] != null ? NetworkImage(doggyData['profileImageUrl']) : null,
              child: doggyData['profileImageUrl'] == null ? const Icon(Icons.pets, size: 40) : null,
            ),
            const SizedBox(height: 8),
            Text(doggyData['name'] ?? 'Unbekannt', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (doggyData['age'] != null) Text('Alter: ${doggyData['age']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, übernehmen')),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({'used': true});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(herrchenId)
        .collection('doggys')
        .doc(doggyId)
        .set({...doggyData, 'uid': doggyId});

    final herrchenDoc = await FirebaseFirestore.instance.collection('users').doc(herrchenId).get();
    final herrchenData = herrchenDoc.data();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(doggyId)
        .collection('assignedHerrchen')
        .doc(herrchenId)
        .set({
      'name': herrchenData?['name'] ?? 'Herrchen',
      'status': 'aktiv',
      'connectedAt': FieldValue.serverTimestamp(),
    });

    _loadData();
  }

  Future<void> _rejectInvite(String inviteId) async {
    await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
      'doggyConfirmed': false,
      'doggyId': null,
    });
    _loadData();
  }

  Future<void> _disconnectDoggy(String doggyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verbindung trennen?'),
        content: const Text('Willst du die Verbindung zu diesem Doggy wirklich aufheben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, trennen')),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('doggys').doc(doggyId).delete();
      await FirebaseFirestore.instance.collection('users').doc(doggyId).collection('assignedHerrchen').doc(user.uid).delete();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Du bist nicht eingeloggt')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Doggys')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // NEU: Einladungscode-Anzeige mit Ablaufdatum
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isCodeLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _einladungscode != null
                        ? Column(
                            children: [
                              QrImageView(
                                data: _einladungscode!,
                                size: 200,
                                version: QrVersions.auto,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Einladungscode:', style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              SelectableText(_einladungscode!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (_codeErstelltAm != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Gültig bis: ${_codeErstelltAm!.add(const Duration(days: 28)).toLocal().toString().substring(0, 16)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _einladungscode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Einladungscode kopiert')),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Kopieren'),
                              ),
                            ],
                          )
                        : const Text(
                            'Fehler beim Laden des Einladungscodes.',
                            style: TextStyle(color: Colors.red),
                          ),
              ),
            ),
            // --- Rest wie bisher ---
            if (_doggys.isEmpty)
              const Column(
                children: [
                  Icon(Icons.pets, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Noch keine Doggys verknüpft.', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Teile deinen QR-Code oder Einladungscode, um einen Doggy hinzuzufügen.', textAlign: TextAlign.center),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Verbundene Doggys', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._doggys.map((doggy) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: doggy['profileImageUrl'] != null
                            ? NetworkImage(doggy['profileImageUrl'])
                            : null,
                        child: doggy['profileImageUrl'] == null ? const Icon(Icons.pets) : null,
                      ),
                      title: Text(doggy['name'] ?? 'Unbenannter Doggy'),
                      subtitle: Text('Level: ${doggy['level'] ?? 1}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        tooltip: 'Verbindung aufheben',
                        onPressed: () => _disconnectDoggy(doggy['uid']),
                      ),
                    ),
                  ))
                ],
              ),

            if (_pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(),
              const Text('Offene Anfragen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ..._pendingRequests.map((invite) => FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(invite['doggyId']).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                  final doggy = snapshot.data!.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: doggy['profileImageUrl'] != null
                            ? NetworkImage(doggy['profileImageUrl'])
                            : null,
                        child: doggy['profileImageUrl'] == null ? const Icon(Icons.pets) : null,
                      ),
                      title: Text(doggy['name'] ?? 'Unbekannt'),
                      subtitle: Text('Alter: ${doggy['age'] ?? '–'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptInvite(invite.id, invite['doggyId']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectInvite(invite.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ))
            ],

            const SizedBox(height: 32),
            const Opacity(
              opacity: 0.5,
              child: ListTile(
                leading: Icon(Icons.map),
                title: Text('Streuner in der Umgebung finden'),
                subtitle: Text('Premium-Inhalt – bald verfügbar'),
                trailing: Icon(Icons.lock),
                onTap: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
