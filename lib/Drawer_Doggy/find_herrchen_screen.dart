import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/Start/qr_scanner_selector.dart';

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
  String? _pendingRequestHerrchenId;
  Map<String, dynamic>? _connectedHerrchen;
  String? _connectedHerrchenId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // 1. Prüfe auf aktive Verbindung
    final hasConnection = await _checkForConnectedHerrchen();

    // 2. Falls keine Verbindung, prüfe Pending-Request
    if (!hasConnection && mounted) {
      await _loadPendingRequestCentral();
    }

    // 3. Ladezustand beenden
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkForConnectedHerrchen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

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

      if (herrchenDoc.exists && mounted) {
        setState(() {
          _connectedHerrchenId = herrchenId;
          _connectedHerrchen = {
            'name': herrchenDoc['benutzername'] ?? 'Unbekannt',
            'profileImageUrl': herrchenDoc['profileImageUrl'],
            'age': herrchenDoc.data()?['age'] ?? null,
            'gender': herrchenDoc['gender'],
          };
        });
        return true;
      }
    }
    return false;
  }

  Future<void> _loadPendingRequestCentral() async {
    print("DEBUG: _loadPendingRequestCentral aufgerufen");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getOwnPendingRequest');
      final result = await callable.call({});
      print("DEBUG: Function result: ${result.data}");

      final data = result.data != null ? Map<String, dynamic>.from(result.data) : null;

      if (data != null && data['pendingRequest'] != null && mounted) {
        final pending = Map<String, dynamic>.from(data['pendingRequest']);
        print("DEBUG pendingRequest: $pending");
        setState(() {
          _pendingHerrchen = {
            'name': pending['herrchenName'] ?? 'Unbekannt',
            'profileImageUrl': pending['profileImageUrl'],
            'age': pending['age'],
            'gender': pending['gender'],
          };
          _pendingRequestHerrchenId = pending['herrchenId'];
          _statusMessage = 'Anfrage läuft, warte auf Bestätigung vom Herrchen.';
        });
      } else if (mounted) {
        setState(() {
          _pendingHerrchen = null;
          _pendingRequestHerrchenId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Fehler beim Laden der Anfrage: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print("DEBUG: _loadPendingRequestCentral fertig");
    }
  }

  Future<void> _sendConnectionRequest(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createPendingRequest');
      final result = await callable.call({'code': code});
      if (result.data['success'] == true) {
        final herrchenRaw = result.data['herrchen'];
        final herrchen = herrchenRaw != null
            ? Map<String, dynamic>.from(herrchenRaw as Map)
            : {};
        setState(() {
          _pendingHerrchen = {
            'name': herrchen['benutzername'] ?? 'Unbekannt',
            'profileImageUrl': herrchen['profileImageUrl'],
            'age': herrchen['age'],
            'gender': herrchen['gender'],
          };
          _pendingRequestHerrchenId = herrchen['herrchenId'];
          _statusMessage = 'Anfrage gesendet! Warte auf Bestätigung.';
        });
      } else {
        setState(() {
          _statusMessage = 'Konnte Anfrage nicht senden.';
        });
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _statusMessage = e.message ?? 'Anfrage fehlgeschlagen.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Unbekannter Fehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _pendingRequestHerrchenId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('cancelPendingRequest');
      await callable.call({'herrchenId': _pendingRequestHerrchenId});
      setState(() {
        _pendingHerrchen = null;
        _pendingRequestHerrchenId = null;
        _statusMessage = 'Anfrage zurückgezogen';
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _statusMessage = e.message ?? 'Zurückziehen fehlgeschlagen.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Unbekannter Fehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchHerrchenPreviewByCode(String code) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('checkInviteCodeAndPreview');
    final result = await callable.call({'code': code});
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> _disconnectHerrchen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verbindung wirklich trennen?'),
        content: const Text(
            'Bist du sicher, dass du die Verbindung zu deinem Herrchen aufheben möchtest?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ja, trennen')),
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

  Future<void> _scanQrCode() async {
    if (_isLoading) return;

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
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Herrchen Anfrage senden?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: preview['profileImageUrl'] != null &&
                        preview['profileImageUrl'] != ''
                    ? NetworkImage(preview['profileImageUrl'])
                    : null,
                child: (preview['profileImageUrl'] == null ||
                        preview['profileImageUrl'] == '')
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                preview['benutzername'] ?? 'Unbekannt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (preview['age'] != null) Text('Alter: ${preview['age']}'),
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
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Code-Eingabe & Buttons immer sichtbar
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Einladungscode eingeben',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final code = _codeController.text.trim();
                            if (code.isNotEmpty) {
                              final preview = await _fetchHerrchenPreviewByCode(code);
                              if (!mounted) return;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Herrchen Anfrage senden?'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundImage: preview['profileImageUrl'] != null &&
                                                preview['profileImageUrl'] != ''
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

                    // LEERLAUF-HINWEIS: Kein Herrchen und keine Pending-Request!
                    if (_pendingHerrchen == null && _connectedHerrchen == null && !_isLoading) ...[
                      const SizedBox(height: 40),
                      const Icon(Icons.search, size: 60, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        "Noch kein Herrchen verbunden.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Bitte gib den Einladungscode deines Herrchens ein oder scanne einen QR-Code.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 2. Pending-Bereich, falls offen
                    if (_pendingHerrchen != null && _connectedHerrchen == null) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Anfrage gesendet an:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: _pendingHerrchen!['profileImageUrl'] != null &&
                                      _pendingHerrchen!['profileImageUrl'] != ''
                                  ? NetworkImage(_pendingHerrchen!['profileImageUrl'])
                                  : null,
                              child: (_pendingHerrchen!['profileImageUrl'] == null ||
                                      _pendingHerrchen!['profileImageUrl'] == '')
                                  ? const Icon(Icons.person, size: 60)
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _pendingHerrchen!['name'] ?? 'Unbekannt',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Warte auf Bestätigung...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 240,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _withdrawRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: StadiumBorder(),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Anfrage zurückziehen',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],

                    // 3. Verbunden-mit-Herrchen-Bereich
                    if (_connectedHerrchen != null) ...[
                      const SizedBox(height: 32),
                      const Text('Du bist verbunden mit:', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _connectedHerrchen!['profileImageUrl'] != null && _connectedHerrchen!['profileImageUrl'] != ''
                            ? NetworkImage(_connectedHerrchen!['profileImageUrl'])
                            : null,
                        child: (_connectedHerrchen!['profileImageUrl'] == null || _connectedHerrchen!['profileImageUrl'] == '')
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _connectedHerrchen!['name'] ?? 'Unbekannt',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _disconnectHerrchen,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Verbindung trennen'),
                      ),
                    ],

                    // Status & Info
                    const SizedBox(height: 20),
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    const Divider(height: 32),
                    const Text(
                      'Demnächst verfügbar (Premium):\nÖffentliche Herrchen entdecken',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
