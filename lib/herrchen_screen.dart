import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/Drawer_herrchen/Herrchen_drawer.dart';
import '/Start/update.dart';
import '/Drawer_Doggy/find_herrchen_screen.dart';

// ----------- Farb-Mapping wie in "Meine Doggys" ------------
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

// ----------- DoggyAvatar Widget ------------
class DoggyAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isSelected;
  final bool hasNewFeed;
  final String? favoriteColorName;
  final double avatarRadius;
  final double fontSize;
  final VoidCallback onTap;

  const DoggyAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    required this.isSelected,
    required this.hasNewFeed,
    this.favoriteColorName,
    this.avatarRadius = 17,
    this.fontSize = 10,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color pawColor = Colors.brown.withOpacity(0.85);
    if (favoriteColorName != null && colorMap.containsKey(favoriteColorName)) {
      pawColor = colorMap[favoriteColorName!]!.withOpacity(0.85);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: isSelected
                    ? Colors.orange
                    : (hasNewFeed ? Colors.yellowAccent : Colors.grey[300]),
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
                child: imageUrl == null
                    ? Icon(Icons.pets, size: 18, color: pawColor)
                    : null,
              ),
              if (hasNewFeed)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      "Bark!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 48,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.orange : Colors.white70,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------- Platzhalter für den NewsFeed ------------
class NewsFeedWidget extends StatelessWidget {
  final String doggyId;
  final String doggyName;
  const NewsFeedWidget({super.key, required this.doggyId, required this.doggyName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Feed für $doggyName wird hier angezeigt.',
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}

// ----------- HerrchenScreen ------------
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
  String? _selectedDoggyId;
  String? _userFavoriteColor; // Lieblingsfarbe des Users aus User-Dokument

  late final String? herrchenUserId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InitService.runOncePerAppStart();
    });

    _loadProfileImageFromFirestore();
    _loadUserFavoriteColor();
    final user = FirebaseAuth.instance.currentUser;
    herrchenUserId = user?.uid;

    _loadDoggys();
  }

  Future<void> _loadUserFavoriteColor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['favoriteColor'] != null) {
      if (mounted) {
        setState(() {
          _userFavoriteColor = data['favoriteColor'] as String;
        });
      }
    }
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

  // DOGGYS und hasNewFeed laden
  Future<void> _loadDoggys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doggysSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('doggys').get();

    final List<Map<String, dynamic>> loaded = [];
    for (var doc in doggysSnap.docs) {
      final doggy = doc.data();
      final doggyId = doc.id;

      // Hole das letzte Login-Datum
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(doggyId).get();
      final lastLogin = userDoc.data()?['lastLogin']?.toDate();

      // Jetzt performant: collectionGroup + userId
      final completionsSnap = (lastLogin == null)
          ? null
          : await FirebaseFirestore.instance
              .collectionGroup('completions')
              .where('userId', isEqualTo: doggyId)
              .where('timestamp', isGreaterThan: lastLogin)
              .get();

      bool hasNewFeed = completionsSnap != null && completionsSnap.docs.isNotEmpty;

      loaded.add({
        ...doggy,
        'id': doggyId,
        'hasNewFeed': hasNewFeed,
      });
    }
    if (mounted) {
      setState(() {
        _doggys.clear();
        _doggys.addAll(loaded);
        if (_selectedDoggyId == null && _doggys.isNotEmpty) {
          _selectedDoggyId = _doggys[0]['id'];
        }
      });
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
              title: const Text('Neue Anfrage!'),
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
                      final callable = FirebaseFunctions.instance
                          .httpsCallable('respondToPendingRequest');
                      await callable
                          .call({'doggyId': doggyId, 'accepted': true});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Anfrage von $doggyName akzeptiert')),
                      );
                      _loadDoggys();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Ablehnen',
                    onPressed: () async {
                      final callable = FirebaseFunctions.instance
                          .httpsCallable('respondToPendingRequest');
                      await callable
                          .call({'doggyId': doggyId, 'accepted': false});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Anfrage von $doggyName abgelehnt')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList());
      },
    );
  }

  // NEUE METHODE: Baut die Doggy-Auswahlleiste für die AppBar
  Widget _buildDoggySelector() {
    if (_doggys.isEmpty) {
      return const SizedBox.shrink(); // Zeigt nichts an, wenn keine Doggys da sind
    }

    return Center(
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: _doggys.length,
          itemBuilder: (context, index) {
            final doggy = _doggys[index];
            final isSelected = _selectedDoggyId == doggy['id'];

            // Nutze hier die Lieblingsfarbe des Users für den Border
            final borderColor = (_userFavoriteColor != null &&
                    colorMap.containsKey(_userFavoriteColor))
                ? colorMap[_userFavoriteColor]!
                : Colors.brown;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDoggyId = doggy['id'];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: borderColor, width: 4)
                        : Border.all(color: Colors.transparent, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: (doggy['profileImageUrl'] != null &&
                            doggy['profileImageUrl'] != '')
                        ? NetworkImage(doggy['profileImageUrl'])
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: (doggy['profileImageUrl'] == null ||
                            doggy['profileImageUrl'] == '')
                        ? Icon(Icons.pets, color: borderColor)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: buildHerrchenDrawer(context, _loadProfileImageFromFirestore, _doggys),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: _doggys.isEmpty || _selectedDoggyId == null
            ? const SizedBox.shrink()
            : _buildDoggySelector(),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPendingRequests(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _doggys.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pets,
                                    size: 54, color: Colors.orangeAccent),
                                const SizedBox(height: 16),
                                const Text(
                                  'Du hast noch keine Doggys.',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.search),
                                  label: const Text('Doggy finden'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const FindHerrchenScreen()),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tippe auf „Doggy finden“, um deinen ersten Doggy zu suchen!',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : (_selectedDoggyId == null
                            ? const Center(
                                child: Text(
                                  'Wähle einen Doggy aus, um deinen individuellen Feed zu sehen.',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final doggy = _doggys.firstWhere(
                                    (d) => d['id'] == _selectedDoggyId,
                                    orElse: () => {},
                                  );
                                  return NewsFeedWidget(
                                    doggyId: doggy['id'] ?? '',
                                    doggyName: doggy['benutzername'] ?? '',
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
