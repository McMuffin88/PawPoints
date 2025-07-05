import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter/material.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<List<Map<String, dynamic>>> _pawpassRequestsFuture;
  bool _refreshingRequests = false;

  @override
  void initState() {
    super.initState();
    _pawpassRequestsFuture = _fetchOpenPawPassRequests();
  }

  Future<List<Map<String, dynamic>>> _fetchOpenPawPassRequests() async {
    // Holt offene Anfragen per Cloud Function (onCall, siehe Backend)
    final callable = FirebaseFunctions.instance.httpsCallable('getAllOpenPawPassRequests');
    final result = await callable();
    final List requests = result.data['requests'] ?? [];
    // Jedes Map enthält id, userName, role, plan, days, requestedAt, etc.
    return List<Map<String, dynamic>>.from(requests);
  }

  Future<void> _refreshRequests() async {
    setState(() {
      _refreshingRequests = true;
      _pawpassRequestsFuture = _fetchOpenPawPassRequests();
    });
    await _pawpassRequestsFuture;
    setState(() {
      _refreshingRequests = false;
    });
  }

  Future<void> _makeUserAdmin(String userId) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    final doc = await ref.get();
    final List<dynamic> oldRoles = (doc.data()?['roles'] ?? []) as List<dynamic>;
    if (oldRoles.contains('admin')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ist schon Admin!')));
      return;
    }
    await ref.update({
      'roles': [...oldRoles, 'admin']
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin-Rechte vergeben!')));
    setState(() {}); // Zum Aktualisieren der Anzeige
  }

  Future<void> _respondToPawPassRequest(String requestId, bool accept) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('respondToPawPassRequest');
      await callable.call({'requestId': requestId, 'accept': accept});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept ? 'PawPass freigeschaltet!' : 'Anfrage abgelehnt!'),
      ));
      await _refreshRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adminpanel')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text('User verwalten', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').orderBy('benutzername').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, idx) {
                      final doc = docs[idx];
                      final data = doc.data() as Map<String, dynamic>;
                      final roles = (data['roles'] as List?)?.join(', ') ?? '';
                      return ListTile(
                        title: Text(data['benutzername'] ?? doc.id),
                        subtitle: Text('Rollen: $roles'),
                        trailing: (roles.contains('admin'))
                            ? const Icon(Icons.admin_panel_settings, color: Colors.blue)
                            : TextButton(
                                child: const Text('Admin vergeben'),
                                onPressed: () => _makeUserAdmin(doc.id),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Offene PawPass-Anfragen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshingRequests ? null : _refreshRequests,
                  tooltip: "Neu laden",
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _pawpassRequestsFuture,
                builder: (context, snapshot) {
                  if (_refreshingRequests) return const Center(child: CircularProgressIndicator());
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Fehler: ${snapshot.error}'));
                  }
                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) return const Text("Keine offenen Anfragen.");
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, idx) {
                      final req = docs[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                        child: ListTile(
                          title: Text('${req['userName'] ?? req['userId']} (${req['role']}, ${req['plan']})'),
                          subtitle: Text('Angefragt: ${req['days']} Tage'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _respondToPawPassRequest(req['id'], true),
                                tooltip: "Annehmen",
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _respondToPawPassRequest(req['id'], false),
                                tooltip: "Ablehnen",
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
