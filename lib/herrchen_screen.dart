import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '/Drawer_herrchen/Herrchen_drawer.dart';
import '/Start/update.dart';
import '/Drawer_Doggy/find_herrchen_screen.dart';
import '/Settings/schriftgroesse_provider.dart';
import '/Settings/schriftgroesse_screen.dart';
import 'Drawer_herrchen/doggyaufgabenform.dart';


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

// ----------- DoggyAvatar Widget (unverändert) ------------
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

// ----------- Platzhalter für den NewsFeed (unverändert) ------------
class NewsFeedWidget extends StatelessWidget {
  final String doggyId;
  final String doggyName;
  const NewsFeedWidget({super.key, required this.doggyId, required this.doggyName});

  @override
  Widget build(BuildContext context) {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context);
    return Center(
      child: Text(
        'Feed für $doggyName wird hier angezeigt.',
        style: TextStyle(color: Colors.grey, fontSize: schriftProvider.allgemeineSchriftgroesse),
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

class _HerrchenScreenState extends State<HerrchenScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _fabKey = GlobalKey(); // Key für den FloatingActionButton
  OverlayEntry? _overlayEntry;
  String? _profileImageUrl;
  final List<Map<String, dynamic>> _doggys = [];
  String? _selectedDoggyId;
  String? _userFavoriteColor;

  late final String? herrchenUserId;

  // Animation related properties
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InitService.runOncePerAppStart();
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Fast animation
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack, // A nice bouncy effect for opening
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _loadProfileImageFromFirestore();
    _loadUserFavoriteColor();
    final user = FirebaseAuth.instance.currentUser;
    herrchenUserId = user?.uid;

    _loadDoggys();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animationController.dispose(); // Dispose the animation controller
    super.dispose();
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


  Future<void> _loadDoggys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doggysSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('doggys').get();

    final List<Map<String, dynamic>> loaded = [];
    for (var doc in doggysSnap.docs) {
      final doggy = doc.data();
      final doggyId = doc.id;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(doggyId).get();
      final lastLogin = userDoc.data()?['lastLogin']?.toDate();

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
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context, listen: false);

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
              title: Text('Neue Anfrage!', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Doggy: $doggyName', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9)),
                  if (requestedAt != null)
                    Text('Angefragt: ${requestedAt.toLocal()}', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9)),
                  Text('Warte auf deine Entscheidung.', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9)),
                ],
              ),
            ),
          );
        }).toList());
      },
    );
  }


  Widget _buildDoggySelector() {
    if (_doggys.isEmpty) {
      return const SizedBox.shrink();
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

  // New custom central hub using OverlayEntry with animations
  void _showCustomCentralHub(BuildContext context) {
    if (_overlayEntry != null) {
      _animationController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
      return;
    }

    final RenderBox fabRenderBox = _fabKey.currentContext?.findRenderObject() as RenderBox;
    final Offset fabOffset = fabRenderBox.localToGlobal(Offset.zero);
    final Size fabSize = fabRenderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background to close on tap outside - now transparent
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _animationController.reverse().then((_) {
                  _overlayEntry?.remove();
                  _overlayEntry = null;
                });
              },
              child: Container(color: Colors.black.withOpacity(0.01)), // Very subtle overlay to catch taps
            ),
          ),
          Positioned(
            right: MediaQuery.of(context).size.width - (fabOffset.dx + fabSize.width),
            bottom: MediaQuery.of(context).size.height - fabOffset.dy + (fabSize.height / 2),
            child: FadeTransition( // Fade animation for the whole menu
              opacity: _fadeAnimation,
              child: ScaleTransition( // Scale animation for the whole menu
                scale: _scaleAnimation,
                alignment: Alignment.bottomRight, // Scale from the FAB's position
                child: Material( // Important for shadows and correct rendering
                  color: Colors.transparent, // Transparent background for the Material containing the menu
                  elevation: 0, // No default elevation for Material, controlled by item boxShadow
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end, // Align menu items to the right
                    children: [
_buildMenuItem(
  context,
  'Neue Aufgabe erstellen',
  Icons.assignment_turned_in,
  Colors.blue,
  () {
showDialog(
  context: context, // Wichtig: dieser Context ist der vom HerrchenScreen und liegt UNTER MultiProvider!
  builder: (dialogContext) => DoggyTaskCreationDialog(
    herrchenId: herrchenUserId!,
    userFavoriteColorName: _userFavoriteColor,
    onTaskAdded: _loadDoggys,
  ),
);

    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  },
),
                      _buildMenuItem(context, 'Neue Belohnung definieren', Icons.card_giftcard, Colors.green, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Platzhalter: Belohnung definieren')));
                        _animationController.reverse().then((_) { _overlayEntry?.remove(); _overlayEntry = null; });
                      }),
                      _buildMenuItem(context, 'Neue Bestrafung festlegen', Icons.warning_amber, Colors.red, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Platzhalter: Bestrafung festlegen')));
                        _animationController.reverse().then((_) { _overlayEntry?.remove(); _overlayEntry = null; });
                      }),
                      // Divider, if desired (now more subtle)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Container(height: 1, width: 150, color: Colors.white24), // More subtle divider
                      ),
                      _buildMenuItem(context, 'Schriftgröße anpassen', Icons.format_size, null, () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SchriftgroesseScreen()));
                        _animationController.reverse().then((_) { _overlayEntry?.remove(); _overlayEntry = null; });
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward(); // Start animation when opening
  }

  // Helper method to build individual menu items - now with refined modern style
  Widget _buildMenuItem(BuildContext context, String text, IconData icon, Color? iconColor, VoidCallback onTap) {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0), // Slightly more padding
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withOpacity(0.7), // A darker, semi-transparent background
            borderRadius: BorderRadius.circular(12.0), // More rounded corners
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8, // More prominent but soft shadow
                spreadRadius: 1,
                offset: Offset(0, 4), // Lifted slightly
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Increased padding
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white70), // Slightly muted white text
              ),
              const SizedBox(width: 12), // Increased spacing
              Icon(icon, color: iconColor ?? Colors.white70, size: 24), // Icon color either specific or muted white, slightly larger
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context);

    // Bestimme die Farbe für den FAB basierend auf der Lieblingsfarbe des Users
    final fabColor = (_userFavoriteColor != null && colorMap.containsKey(_userFavoriteColor))
        ? colorMap[_userFavoriteColor]!
        : Colors.orange; // Fallback-Farbe

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
      floatingActionButton: FloatingActionButton(
        key: _fabKey, // Den Key hier zuweisen
        onPressed: () => _showCustomCentralHub(context), // Changed to new custom hub function
        child: const Icon(Icons.add),
        tooltip: 'Aufgabe, Belohnung oder Bestrafung erstellen',
        backgroundColor: fabColor,
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
                                Text(
                                  'Du hast noch keine Doggys.',
                                  style: TextStyle(
                                      fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.search),
                                  label: Text('Doggy finden', style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse)),
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
                                Text(
                                  'Tippe auf „Doggy finden“, um deinen ersten Doggy zu suchen!',
                                  style: TextStyle(
                                      fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : (_selectedDoggyId == null
                            ? Center(
                                child: Text(
                                  'Wähle einen Doggy aus, um deinen individuellen Feed zu sehen.',
                                  style: TextStyle(
                                      fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.grey),
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