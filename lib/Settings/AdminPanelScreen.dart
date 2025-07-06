import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _pawpassRequestsFuture;
  bool _refreshingRequests = false;
  late TabController _tabController;

  // Status-Optionen für Bugs
  final List<String> bugStatusOptions = ['offen', 'in Bearbeitung', 'erledigt', 'geschlossen'];

  // Version & Filter
  String? _currentVersion;
  String? _downloadUrl;
  String? _changelog;
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _changelogController = TextEditingController();

  // Filteroptionen für Bugs
  bool _hideErledigte = false;
  bool _hideErledigteAlteVersion = false;

  @override
  void initState() {
    super.initState();
    _pawpassRequestsFuture = _fetchOpenPawPassRequests();
    _tabController = TabController(length: 4, vsync: this);
    _fetchVersionInfo();
  }

  Future<List<Map<String, dynamic>>> _fetchOpenPawPassRequests() async {
    final callable = FirebaseFunctions.instance.httpsCallable('getAllOpenPawPassRequests');
    final result = await callable();
    final List requests = result.data['requests'] ?? [];
    return requests.map<Map<String, dynamic>>(
      (item) => Map<String, dynamic>.from(item as Map)
    ).toList();
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

  Future<void> _makeUserAdmin(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adminrechte vergeben'),
        content: Text('Soll $name wirklich zum Admin gemacht werden?'),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(child: const Text('Ja, Admin vergeben'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirm != true) return;

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
    setState(() {});
  }

  Future<void> _removeUserAdmin(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin entfernen'),
        content: Text('Soll $name wirklich die Adminrechte verlieren?'),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(child: const Text('Ja, entfernen'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirm != true) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(userId);
    final doc = await ref.get();
    final List<dynamic> oldRoles = (doc.data()?['roles'] ?? []) as List<dynamic>;
    if (!oldRoles.contains('admin')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ist kein Admin!')));
      return;
    }
    await ref.update({
      'roles': oldRoles.where((r) => r != 'admin').toList()
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin entfernt!')));
    setState(() {});
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

  Future<void> _fetchVersionInfo() async {
    final doc = await FirebaseFirestore.instance.collection('meta').doc('version').get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _currentVersion = data['version'] ?? '';
      _downloadUrl = data['downloadUrl'] ?? '';
      _changelog = data['changelog'] ?? '';
      _versionController.text = _currentVersion ?? '';
      _changelogController.text = _changelog ?? '';
    });
  }

  Future<void> _saveVersionInfo(String newVersion) async {
    await FirebaseFirestore.instance.collection('meta').doc('version').update({
      'version': newVersion,
    });
    await _fetchVersionInfo();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Version aktualisiert!")));
  }

  Future<void> _saveChangelog(String newChangelog) async {
    await FirebaseFirestore.instance.collection('meta').doc('version').update({
      'changelog': newChangelog,
    });
    await _fetchVersionInfo();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changelog aktualisiert!")));
  }

  void _increaseVersion() {
    final parts = (_versionController.text.isNotEmpty ? _versionController.text : (_currentVersion ?? "0.0.0")).split('.');
    if (parts.length == 3) {
      int patch = int.tryParse(parts[2]) ?? 0;
      patch += 1;
      final newVersion = "${parts[0]}.${parts[1]}.$patch";
      setState(() {
        _versionController.text = newVersion;
      });
    }
  }

  // --- Hilfsfunktion zum Versionsvergleich (z. B. 0.0.100 > 0.0.98 etc.) ---
  bool isVersionSmaller(String? bugVersion, String? refVersion, {int minDiff = 2}) {
    if (bugVersion == null || refVersion == null) return false;
    final bugParts = bugVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final refParts = refVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (bugParts.length != 3 || refParts.length != 3) return false;
    // Nur Patch vergleichen:
    return refParts[0] == bugParts[0] &&
        refParts[1] == bugParts[1] &&
        (refParts[2] - bugParts[2]) >= minDiff;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _versionController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  Widget _buildUserVerwaltung() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('benutzername').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.only(top: 10),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 6),
          itemBuilder: (ctx, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final rolesList = (data['roles'] as List?) ?? [];
            final roles = rolesList.join(', ');
            final String benutzername = data['benutzername'] ?? doc.id;
            final String email = data['email'] ?? '';
            final String rolle = rolesList.contains('herrchen')
                ? 'Herrchen'
                : (rolesList.contains('doggy') ? 'Doggy' : '-');
            final bool isPremium = ((data['premium'] ?? {})[rolle.toLowerCase()] ?? false) == true;
            final bool isAdmin = rolesList.contains('admin');
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Text(benutzername.isNotEmpty ? benutzername[0].toUpperCase() : '?'),
              ),
              title: Text('$benutzername (${rolle})',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('E-Mail: $email', style: const TextStyle(fontSize: 12)),
                  Text('Rollen: $roles', style: const TextStyle(fontSize: 12)),
                  if (isPremium) const Text('Premium ✔', style: TextStyle(color: Colors.amber, fontSize: 12)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                      tooltip: "Admin entfernen",
                      onPressed: () => _removeUserAdmin(doc.id, benutzername),
                    ),
                  if (!isAdmin)
                    TextButton(
                      child: const Text('Admin vergeben'),
                      onPressed: () => _makeUserAdmin(doc.id, benutzername),
                    ),
                ],
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Details: $benutzername'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('E-Mail: $email'),
                        Text('Rollen: $roles'),
                        Text('Premium: ${isPremium ? "Ja" : "Nein"}'),
                        const SizedBox(height: 8),
                        const Text('Offene Anfragen (PawPass):'),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _pawpassRequestsFuture,
                          builder: (context, snap) {
                            final relevant = (snap.data ?? [])
                                .where((req) => req['userId'] == doc.id)
                                .toList();
                            if (relevant.isEmpty) {
                              return const Text('Keine offenen Anfragen.');
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: relevant.map((req) {
                                return Text('${req['plan']} (${req['days']} Tage)');
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPawPassAnfragen() {
    return RefreshIndicator(
      onRefresh: _refreshRequests,
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
          if (docs.isEmpty) return const Padding(
              padding: EdgeInsets.all(12), child: Text("Keine offenen Anfragen."));
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
    );
  }

  Widget _buildBugVerwaltung() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Erledigte Bugs ausblenden", style: TextStyle(fontSize: 14)),
                  value: _hideErledigte,
                  onChanged: (val) {
                    setState(() {
                      _hideErledigte = val ?? false;
                      if (_hideErledigte) _hideErledigteAlteVersion = false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Erledigte + alte Version ausblenden", style: TextStyle(fontSize: 14)),
                  value: _hideErledigteAlteVersion,
                  onChanged: (val) {
                    setState(() {
                      _hideErledigteAlteVersion = val ?? false;
                      if (_hideErledigteAlteVersion) _hideErledigte = false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('feedback')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final bugs = snapshot.data!.docs;
              if (bugs.isEmpty) return const Padding(
                  padding: EdgeInsets.all(12), child: Text('Keine Bugs gefunden.'));
              // Filter anwenden
              final List<QueryDocumentSnapshot> filtered = bugs.where((bug) {
                final data = bug.data() as Map<String, dynamic>;
                final status = (data['status'] ?? 'offen').toString();
                final String? appVersion = data['appVersion'];
                if (_hideErledigte) {
                  return status != 'erledigt' && status != 'geschlossen';
                }
                if (_hideErledigteAlteVersion && (status == 'erledigt' || status == 'geschlossen')) {
                  // Mindestens -0.0.002 zum aktuellen Patch zurückliegend:
                  return !isVersionSmaller(appVersion, _currentVersion, minDiff: 2);
                }
                return true;
              }).toList();

              return ListView.separated(
                padding: const EdgeInsets.only(top: 10),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, idx) {
                  final bug = filtered[idx];
                  final data = bug.data() as Map<String, dynamic>;
                  final String bugId = bug.id;
                  final String message = data['message'] ?? '';
                  final String status = data['status'] ?? 'offen';
                  final String category = data['category'] ?? '';
                  final String appVersion = data['appVersion'] ?? '';
                  final int? bugNumber = data['bugNumber'];
                  final String deviceInfo = data['deviceInfo'] ?? '';
                  final int? severity = data['severity'];
                  final String os = data['os'] ?? '';
                  final String dateString = data['timestamp']?.toString().split(' ').take(5).join(' ') ?? '';
                  // Screenshots
                  List<String> screenshots = [];
                  if (data.containsKey('screenshotUrls') && data['screenshotUrls'] is List) {
                    screenshots = (data['screenshotUrls'] as List).whereType<String>().toList();
                  } else if (data.containsKey('screenshotUrl') && data['screenshotUrl'] is String) {
                    screenshots = [data['screenshotUrl']];
                  }

                  return Card(
                    margin: EdgeInsets.zero,
                    color: status == 'erledigt' || status == 'geschlossen' ? Colors.green[50] : null,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.bug_report, color: Colors.redAccent, size: 22),
                      title: Text('Bug #${bugNumber ?? ''}  (${category})', style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(message, style: const TextStyle(fontSize: 13)),
                            ),
                          Row(
                            children: [
                              if (deviceInfo.isNotEmpty) Text('Gerät: $deviceInfo  ', style: const TextStyle(fontSize: 11)),
                              if (os.isNotEmpty) Text('OS: $os  ', style: const TextStyle(fontSize: 11)),
                              if (appVersion.isNotEmpty) Text('App: $appVersion', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          if (dateString.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text("Gemeldet: $dateString", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          if (severity != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text("Severity: $severity", style: const TextStyle(fontSize: 11, color: Colors.orange)),
                            ),
                          if (screenshots.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                              child: SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: screenshots.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, idx) {
                                    final url = screenshots[idx];
                                    return GestureDetector(
                                      onTap: () async {
                                        if (await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: DropdownButton<String>(
                        value: status,
                        dropdownColor: Colors.grey[900],
                        underline: Container(),
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        items: bugStatusOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? newStatus) async {
                          if (newStatus == null) return;
                          await FirebaseFirestore.instance
                              .collection('feedback')
                              .doc(bugId)
                              .update({'status': newStatus});
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Status auf "$newStatus" geändert')),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVersionPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Versionierung & Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 18),
              Text('Aktuelle Version: ${_currentVersion ?? "-"}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _versionController,
                      decoration: const InputDecoration(labelText: "Version ändern (z.B. 0.0.390)"),
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveVersionInfo(_versionController.text);
                    },
                    child: const Text('Übernehmen'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _increaseVersion,
                child: const Text('Version +0.0.001'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 18),
              const Text("Direkter Download-Link:"),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  if (_downloadUrl == null) {
                    return const CircularProgressIndicator();
                  }
                  if (_downloadUrl!.isEmpty) {
                    return const Text("Kein Link vorhanden.", style: TextStyle(color: Colors.grey));
                  }
                  return InkWell(
                    child: Text(_downloadUrl!,
                        style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline)),
                    onTap: () async {
                      if (await canLaunchUrl(Uri.parse(_downloadUrl!))) {
                        await launchUrl(Uri.parse(_downloadUrl!));
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text("Changelog bearbeiten:"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _changelogController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: "Changelog"),
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveChangelog(_changelogController.text);
                    },
                    child: const Text('Übernehmen'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_changelog != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Changelog aktuell: $_changelog', style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adminpanel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: "Nutzer"),
            Tab(icon: Icon(Icons.workspace_premium), text: "Premium-Anfragen"),
            Tab(icon: Icon(Icons.bug_report), text: "Bugs"),
            Tab(icon: Icon(Icons.system_update_alt), text: "Version"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserVerwaltung(),
          _buildPawPassAnfragen(),
          _buildBugVerwaltung(),
          _buildVersionPanel(),
        ],
      ),
    );
  }
}
