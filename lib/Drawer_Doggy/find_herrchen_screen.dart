import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pawpoints/Start/qr_scanner_selector.dart';

class FindHerrchenScreen extends StatefulWidget {
  const FindHerrchenScreen({super.key});

  @override
  State<FindHerrchenScreen> createState() => _FindHerrchenScreenState();
}

class _FindHerrchenScreenState extends State<FindHerrchenScreen> {
  final _codeController = TextEditingController();
  String? _statusMessage;
  bool _isLoading = false;
  Map<String, dynamic>? _pendingHerrchen;
  Map<String, dynamic>? _connectedHerrchen;
  String? _inviteDocId;
  String? _connectedHerrchenId;

  @override
  void initState() {
    super.initState();
    _checkForConnectedHerrchen();
    _checkForPendingInvite();
  }

  Future<void> _checkForConnectedHerrchen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assignedHerrchen')
        .get();

    if (snapshot.docs.isNotEmpty) {
      final herrchenId = snapshot.docs.first.id;
      final herrchenDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(herrchenId)
          .get();

      if (herrchenDoc.exists) {
        setState(() {
          _connectedHerrchenId = herrchenId;
          _connectedHerrchen = {
            'name': herrchenDoc['name'] ?? 'Unbekannt',
            'profileImageUrl': herrchenDoc['profileImageUrl'],
            'age': herrchenDoc['age'],
          };
        });
      }
    }
  }

  Future<void> _disconnectHerrchen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verbindung wirklich trennen?'),
        content: const Text(
            'Bist du sicher, dass du die Verbindung zu deinem Herrchen aufheben möchtest?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, trennen')),
        ],
      ),
    );

    if (confirmed == true && _connectedHerrchenId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignedHerrchen')
          .doc(_connectedHerrchenId!)
          .delete();

      setState(() {
        _connectedHerrchen = null;
        _connectedHerrchenId = null;
        _statusMessage = 'Verbindung wurde aufgehoben';
      });
    }
  }

  Future<void> _checkForPendingInvite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('invites')
        .where('doggyConfirmed', isEqualTo: true)
        .where('used', isEqualTo: false)
        .where('doggyId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final herrchenId = doc['herrchenId'];
      final herrchenDoc =
          await FirebaseFirestore.instance.collection('users').doc(herrchenId).get();
      final doggys = await FirebaseFirestore.instance
          .collection('users')
          .doc(herrchenId)
          .collection('doggys')
          .get();

      final data = herrchenDoc.data();
      if (data == null) return;

      setState(() {
        _pendingHerrchen = {
          'name': data['name'] ?? 'Unbekannt',
          'age': data['age'] ?? '–',
          'profileImageUrl': data['profileImageUrl'],
          'doggyCount': doggys.size,
        };
        _inviteDocId = doc.id;
      });
    }
  }

  Future<void> _checkInviteCode(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _pendingHerrchen = null;
    });

    final doc = await FirebaseFirestore.instance.collection('invites').doc(code).get();

    if (!doc.exists) {
      setState(() {
        _statusMessage = 'Einladungscode ungültig.';
        _isLoading = false;
      });
      return;
    }

    final data = doc.data()!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (data['used'] == true) {
      setState(() {
        _statusMessage = 'Dieser Code wurde bereits verwendet.';
        _isLoading = false;
      });
      return;
    }

    if (data['doggyConfirmed'] == true && data['doggyId'] != user.uid) {
      setState(() {
        _statusMessage = 'Einladung wurde bereits von einem anderen Doggy angenommen.';
        _isLoading = false;
      });
      return;
    }

    final herrchenId = data['herrchenId'];
    final herrchenDoc =
        await FirebaseFirestore.instance.collection('users').doc(herrchenId).get();
    final doggys = await FirebaseFirestore.instance
        .collection('users')
        .doc(herrchenId)
        .collection('doggys')
        .get();

    final herrchenData = herrchenDoc.data();
    if (herrchenData == null) {
      setState(() {
        _statusMessage = 'Herrchen-Daten konnten nicht geladen werden.';
        _isLoading = false;
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Herrchen verbinden?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: herrchenData['profileImageUrl'] != null
                  ? NetworkImage(herrchenData['profileImageUrl'])
                  : null,
              child: herrchenData['profileImageUrl'] == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(herrchenData['name'] ?? 'Unbekannt',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (herrchenData['age'] != null) Text('Alter: ${herrchenData['age']}'),
            Text('Hat ${doggys.size} Doggy(s)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, verbinden')),
        ],
      ),
    );

    if (confirm != true) {
      setState(() => _isLoading = false);
      return;
    }

    await FirebaseFirestore.instance.collection('invites').doc(code).update({
      'doggyConfirmed': true,
      'doggyId': user.uid,
    });

    setState(() {
      _pendingHerrchen = {
        'name': herrchenData['name'] ?? 'Unbekannt',
        'age': herrchenData['age'] ?? '–',
        'profileImageUrl': herrchenData['profileImageUrl'],
        'doggyCount': doggys.size,
      };
      _inviteDocId = code;
      _statusMessage = null;
      _isLoading = false;
    });
  }

  Future<void> _withdrawRequest() async {
    if (_inviteDocId == null) return;
    await FirebaseFirestore.instance.collection('invites').doc(_inviteDocId).update({
      'doggyConfirmed': false,
      'doggyId': null,
    });

    setState(() {
      _pendingHerrchen = null;
      _inviteDocId = null;
      _statusMessage = 'Anfrage zurückgezogen';
    });
  }

  @override
  Widget build(BuildContext context) {
    const isMobile = !kIsWeb;

    return Scaffold(
      appBar: AppBar(title: const Text('Herrchen finden')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_connectedHerrchen != null) ...[
                    const Text('Verbunden mit Herrchen:'),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _connectedHerrchen!['profileImageUrl'] != null
                          ? NetworkImage(_connectedHerrchen!['profileImageUrl'])
                          : null,
                      child: _connectedHerrchen!['profileImageUrl'] == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectedHerrchen!['name'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_connectedHerrchen!['age'] != null)
                      Text('Alter: ${_connectedHerrchen!['age']}'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _disconnectHerrchen,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Verbindung aufheben'),
                    ),
                    const Divider(height: 32),
                  ],

                  if (_pendingHerrchen != null) ...[
                    const Text('Anfrage gesendet an:'),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _pendingHerrchen!['profileImageUrl'] != null
                          ? NetworkImage(_pendingHerrchen!['profileImageUrl'])
                          : null,
                      child: _pendingHerrchen!['profileImageUrl'] == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(_pendingHerrchen!['name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_pendingHerrchen!['age'] != null)
                      Text('Alter: ${_pendingHerrchen!['age']}'),
                    Text('Hat ${_pendingHerrchen!['doggyCount']} Doggy(s)'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _withdrawRequest,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Anfrage zurückziehen'),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Einladungscode eingeben',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _checkInviteCode(_codeController.text.trim()),
                          child: const Text('Einladen'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () async {
                            if (kIsWeb) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('QR-Scan ist im Web nicht verfügbar')),
                              );
                            } else {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MobileQRScreen()),
                              );

                              if (result is String && result.isNotEmpty) {
                                _codeController.text = result;
                                _checkInviteCode(result);
                              }
                            }
                          },
                          child: const Text('QR scannen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 20),
                    const Divider(height: 32),
                    const Text(
                      'Demnächst verfügbar (Premium):\nÖffentliche Herrchen entdecken',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ]
                ],
              ),
      ),
    );
  }
}