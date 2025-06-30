import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/Drawer_herrchen/Herrchen_drawer.dart';
import '/Start/update.dart';

class HerrchenScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const HerrchenScreen({super.key, this.onProfileTap});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _profileImageUrl;
  final List<Map<String, dynamic>> _doggys = [];

  late final String? herrchenUserId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InitService.runOncePerAppStart();
    });

    _loadProfileImageFromFirestore();

    final user = FirebaseAuth.instance.currentUser;
    herrchenUserId = user?.uid;
  }

  Future<void> _loadProfileImageFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['profileImageUrl'] != null) {
      if (mounted) {
        setState(() {
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    }
  }

  Widget _buildProfileIcon() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, __) {
          debugPrint('[WARN] Bild konnte nicht geladen werden.');
        },
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        child: Icon(Icons.account_circle),
      );
    }
  }

  Widget _buildPendingRequests() {
    if (herrchenUserId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pendingRequests')
          .where('herrchenId', isEqualTo: herrchenUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox();
        return Column(
          children: docs.map((doc) {
            final pending = doc.data() as Map<String, dynamic>;
            final doggyName = pending['doggyName'] ?? 'Unbekannt';
            final doggyAvatar = pending['doggyAvatarUrl'];
            final doggyId = pending['doggyId'] ?? '';
            final requestedAt = (pending['requestedAt'] is Timestamp)
                ? (pending['requestedAt'] as Timestamp).toDate()
                : null;

            return Card(
              color: Colors.transparent,
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              child: ListTile(
                leading: doggyAvatar != null && doggyAvatar != ''
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(doggyAvatar),
                      )
                    : const CircleAvatar(child: Icon(Icons.pets)),
                title: Text('Neue Anfrage!'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doggy: $doggyName'),
                    if (requestedAt != null)
                      Text('Angefragt: ${requestedAt.toLocal()}'),
                    const Text('Warte auf deine Entscheidung.'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'Annehmen',
                      onPressed: () async {
                        final callable = FirebaseFunctions.instance.httpsCallable('respondToPendingRequest');
                        await callable.call({'doggyId': doggyId, 'accepted': true});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Anfrage von $doggyName akzeptiert')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Ablehnen',
                      onPressed: () async {
                        final callable = FirebaseFunctions.instance.httpsCallable('respondToPendingRequest');
                        await callable.call({'doggyId': doggyId, 'accepted': false});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Anfrage von $doggyName abgelehnt')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: buildHerrchenDrawer(context, _loadProfileImageFromFirestore, _doggys),
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
        actions: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildProfileIcon(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PENDING REQUESTS OBEN ANZEIGEN
            _buildPendingRequests(),
            const SizedBox(height: 24),
            // DEIN URSPRÜNGLICHER BODY BLEIBT ERHALTEN!
            const Center(
              child: Text(
                'Aufgaben werden hier angezeigt.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
