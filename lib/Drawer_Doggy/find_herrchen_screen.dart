import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  String? _connectedHerrchenId;
  String? _pendingRequestHerrchenId;

  @override
  void initState() {
    super.initState();
    _checkForConnectedHerrchen();
    _checkForPendingRequest();
  }

  /// Prüft, ob bereits ein Herrchen zugeordnet ist
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
            'gender': herrchenDoc['gender'],
          };
        });
      }
    }
  }

  /// Prüft, ob eine offene Verbindungsanfrage existiert (Doggy → Herrchen, noch nicht bestätigt)
  Future<void> _checkForPendingRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collectionGroup('pendingDoggyRequests')
        .where('doggyId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final herrchenRef = doc.reference.parent.parent;
      if (herrchenRef != null) {
        final herrchenDoc = await herrchenRef.get();
        if (herrchenDoc.exists) {
          setState(() {
            _pendingRequestHerrchenId = herrchenRef.id;
            _pendingHerrchen = {
              'name': herrchenDoc['name'] ?? 'Unbekannt',
              'profileImageUrl': herrchenDoc['profileImageUrl'],
              'age': herrchenDoc['age'],
              'gender': herrchenDoc['gender'],
            };
            _statusMessage = 'Anfrage läuft, warte auf Bestätigung vom Herrchen.';
          });
          return;
        }
      }
    }
    // Keine offene Anfrage
    setState(() {
      _pendingHerrchen = null;
      _pendingRequestHerrchenId = null;
      _statusMessage = null;
    });
  }

  Future<void> _sendConnectionRequest(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestConnectionToHerrchen');
      final result = await callable.call({'code': code});
      if (result.data['success'] == true) {
        await _checkForPendingRequest();
        setState(() {
          _statusMessage = 'Anfrage gesendet! Warte auf Bestätigung.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Konnte Anfrage nicht senden.';
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _statusMessage = e.message ?? 'Anfrage fehlgeschlagen.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Unbekannter Fehler: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _pendingRequestHerrchenId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_pendingRequestHerrchenId)
        .collection('pendingDoggyRequests')
        .doc(user.uid)
        .delete();

    setState(() {
      _pendingHerrchen = null;
      _pendingRequestHerrchenId = null;
      _statusMessage = 'Anfrage zurückgezogen';
    });
  }

  Future<Map<String, dynamic>> _fetchHerrchenPreviewByCode(String code) async {
    final callable = FirebaseFunctions.instance.httpsCallable('checkInviteCodeAndPreview');
    final result = await callable.call({'code': code});
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> _disconnectHerrchen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verbindung wirklich trennen?'),
        content: const Text('Bist du sicher, dass du die Verbindung zu deinem Herrchen aufheben möchtest?'),
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

  String _getGenderText(String? gender) {
    switch (gender) {
      case 'male':
        return 'Männlich';
      case 'female':
        return 'Weiblich';
      case 'diverse':
        return 'Divers';
      default:
        return 'Unbekannt';
    }
  }

  // --- QR Scanner wiederhergestellt, genau wie ursprünglich ---
  Future<void> _scanQrCode() async {
    if (_isLoading) return; // Falls noch am Laden, abbrechen

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR-Scan ist im Web nicht verfügbar')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MobileQRScreen()),
    );

    if (result is String && result.isNotEmpty) {
      _codeController.text = result;

      final preview = await _fetchHerrchenPreviewByCode(result);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Herrchen Anfrage senden?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: preview['profileImageUrl'] != null && preview['profileImageUrl'] != ''
                    ? NetworkImage(preview['profileImageUrl'])
                    : null,
                child: (preview['profileImageUrl'] == null || preview['profileImageUrl'] == '')
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                preview['benutzername'] ?? 'Unbekannt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (preview['age'] != null)
                Text('Alter: ${preview['age']}'),
              if (preview['gender'] != null)
                Text('Geschlecht: ${_getGenderText(preview['gender'])}'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Anfrage senden')),
          ],
        ),
      );
      if (confirm == true) {
        await _sendConnectionRequest(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    if (_connectedHerrchen!['gender'] != null)
                      Text('Geschlecht: ${_getGenderText(_connectedHerrchen!['gender'])}'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _disconnectHerrchen,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Verbindung aufheben'),
                    ),
                    const Divider(height: 32),
                  ],

                  // PENDING-ANFRAGE WIRD IMMER DIREKT ANGEZEIGT!
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
                    if (_pendingHerrchen!['gender'] != null)
                      Text('Geschlecht: ${_getGenderText(_pendingHerrchen!['gender'])}'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _withdrawRequest,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Anfrage zurückziehen'),
                    ),
                    if (_statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 16),
                        ),
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
                          onPressed: () async {
                            // Prüfe immer erst, ob ein Pending existiert!
                            await _checkForPendingRequest();
                            if (_pendingHerrchen != null) {
                              setState(() {
                                _statusMessage = 'Du hast bereits eine offene Anfrage. Bitte zuerst zurückziehen.';
                              });
                              return;
                            }
                            final code = _codeController.text.trim();
                            if (code.isNotEmpty) {
                              final preview = await _fetchHerrchenPreviewByCode(code);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Herrchen Anfrage senden?'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundImage: preview['profileImageUrl'] != null && preview['profileImageUrl'] != ''
                                            ? NetworkImage(preview['profileImageUrl'])
                                            : null,
                                        child: (preview['profileImageUrl'] == null || preview['profileImageUrl'] == '')
                                            ? const Icon(Icons.person, size: 40)
                                            : null,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        preview['benutzername'] ?? 'Unbekannt',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (preview['age'] != null)
                                        Text('Alter: ${preview['age']}'),
                                      if (preview['gender'] != null)
                                        Text('Geschlecht: ${_getGenderText(preview['gender'])}'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Abbrechen')),
                                    ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Anfrage senden')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _sendConnectionRequest(code);
                              }
                            }
                          },
                          child: const Text('Anfrage senden'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _scanQrCode,
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
