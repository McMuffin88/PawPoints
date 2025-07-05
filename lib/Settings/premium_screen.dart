import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';

final Map<String, Color> colorMap = {
  'Rot': Colors.red,
  'Blau': Colors.blue,
  'Grun': Colors.green,
  'Gelb': Colors.yellow,
  'Orange': Colors.orange,
  'Lila': Colors.purple,
  'Pink': Colors.pink,
  'Schwarz': Colors.black,
  'Weiß': Colors.white,
  'Grau': Colors.grey,
  'Braun': Colors.brown,
};

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with SingleTickerProviderStateMixin {
  Color _favoriteColor = Colors.brown;
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  bool _pawPassAlreadyActivated = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteColor();
    _checkPawPassActivatedOnce();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeInAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<void> _checkPawPassActivatedOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final already = doc.data()?['pawpassActivatedOnce'] == true;
    setState(() {
      _pawPassAlreadyActivated = already;
      _loading = false;
    });
  }

  Future<String?> _getUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;

    final roles = data['roles'];
    if (roles is List && roles.contains('herrchen')) return 'herrchen';
    if (roles is List && roles.contains('doggy')) return 'doggy';

    // Fallback falls einzelne Felder
    if (data['doggy'] == true) return 'doggy';
    if (data['herrchen'] == true) return 'herrchen';

    return null;
  }

  Future<void> _requestPremium(String plan, int tage) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final role = await _getUserRole();
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rolle nicht erkannt')),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestPremium');
      final result = await callable.call({
        'userId': uid,
        'role': role,
        'plan': plan,
        'days': tage,
      });

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anfrage für $plan Premium gesendet')),
        );
        setState(() {
          _pawPassAlreadyActivated = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anfrage nicht erfolgreich.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Du hast den Gratiszeitraum bereits genutzt!')),
        );
        setState(() {
          _pawPassAlreadyActivated = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Senden: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unbekannter Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('PawPass'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: _favoriteColor, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Werde Teil des PawPass-Programms',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _favoriteColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Exklusive Inhalte für dich & deinen Doggy. Getrennt für Herrchen und Doggys sichtbar.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildPromoBox(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: _buildFeatureSection(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSharedFeatures(),
                  const SizedBox(height: 20),
                  if (!_pawPassAlreadyActivated)
                    OutlinedButton(
                      onPressed: _showPlanDialog,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _favoriteColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        backgroundColor: Colors.transparent,
                      ),
                      child: Text(
                        'PawPass jetzt aktivieren',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _favoriteColor,
                        ),
                      ),
                    ),
                  if (_pawPassAlreadyActivated)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _favoriteColor, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: _favoriteColor),
                          const SizedBox(width: 8),
                          Text(
                            'Du hast den Gratiszeitraum bereits genutzt.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _favoriteColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPromoBox() {
    final glow = 0.5 + 0.5 * _controller.value;
    final borderGlowColor = _favoriteColor.withOpacity(glow);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Align(
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderGlowColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: borderGlowColor,
                blurRadius: 12,
                spreadRadius: 1.5,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.card_giftcard, color: _favoriteColor, size: 36),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎁 4 Wochen gratis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _favoriteColor)),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        'Diese Zeit wird automatisch an eine 3-monatige Mitgliedschaft drangehangen, sobald du kündigst.',
                    child: Text('*', style: TextStyle(color: _favoriteColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Bei deiner ersten PawPass-Aktivierung bekommst du 4 Wochen geschenkt.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSection() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureColumn('Für Herrchen', herrchenFeatures),
        ),
        Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 12)),
        Expanded(
          child: _buildFeatureColumn('Für Doggys', doggyFeatures),
        ),
      ],
    );
  }

  Widget _buildFeatureColumn(String title, List<Map<String, dynamic>> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...features.map(_buildFeatureTile),
      ],
    );
  }

  Widget _buildSharedFeatures() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _favoriteColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.handshake, size: 20, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Gemeinsame PawPass-Vorteile',
                style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Beide Seiten benötigen einen aktiven PawPass, um diese Funktionen nutzen zu können.',
              child: Text('*', style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: 18)),
            )
          ]),
          const SizedBox(height: 12),
          ...gemeinsameFeatures.map(_buildFeatureTile),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(Map<String, dynamic> feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(feature['icon'], color: Colors.white70, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(feature['title'], style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(feature['description'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (feature['comingSoon'] == true)
            Positioned(
              right: -4,
              top: -2,
              child: Transform.rotate(
                angle: -pi / 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPlanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('PawPass aktivieren', style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption("1 Monat", "2,99 € / Monat", Icons.calendar_view_month, 30),
            const SizedBox(height: 12),
            _buildPlanOption("3 Monate", "5,99 € einmalig (1,99 € / Monat)", Icons.calendar_today, 90, recommended: true),
            const SizedBox(height: 12),
            _buildPlanOption("12 Monate", "17,99 € einmalig (1,49 € / Monat)", Icons.event_available, 365),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Abbrechen"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(String title, String price, IconData icon, int tage, {bool recommended = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _requestPremium(title, tage);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: recommended ? _favoriteColor : Colors.grey, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: _favoriteColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(price, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            if (recommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _favoriteColor, borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  'Empfohlen',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      ),
    );
  }

  final herrchenFeatures = [
    {
      'icon': Icons.groups,
      'title': 'Bis zu 5 Doggys',
      'description': 'Verwalte mehrere Doggys gleichzeitig.',
    },
    {
      'icon': Icons.emoji_events,
      'title': 'Wöchentliche Herausforderungen',
      'description': 'Starte Challenges für deine Doggys.',
    },
    {
      'icon': Icons.pets,
      'title': 'Streuner finden',
      'description': 'Entdecke Doggys in deiner Umgebung.',
      'comingSoon': true,
    },
    {
      'icon': Icons.save,
      'title': 'Aufgabenvorlagen speichern',
      'description': 'Bald kannst du deine Aufgaben speichern.',
      'comingSoon': true,
    },
  ];

  final doggyFeatures = [
    {
      'icon': Icons.group_add,
      'title': 'Bis zu 5 Herrchen',
      'description': 'Ein Doggy kann mit mehreren Herrchen verbunden sein.',
    },
    {
      'icon': Icons.search,
      'title': 'Herrchen suchen',
      'description': 'Finde passende Herrchen in deiner Umgebung.',
      'comingSoon': true,
    },
    {
      'icon': Icons.palette,
      'title': 'Mehr Icons bei Aufgaben',
      'description': 'Bald bis zu 8 Icons zur Auswahl.',
      'comingSoon': true,
    },
  ];

  final gemeinsameFeatures = [
    {
      'icon': Icons.color_lens,
      'title': 'Individuelles Design',
      'description': 'Passe die App an deine Lieblingsfarbe an.',
    },
    {
      'icon': Icons.comment,
      'title': 'Bestrafungen kommentieren',
      'description': 'Doggy und Herrchen können Feedback geben und sehen.',
      'comingSoon': true,
    },
    {
      'icon': Icons.card_giftcard,
      'title': 'Belohnungen vorschlagen',
      'description': 'Beide Seiten können Vorschläge machen.',
      'comingSoon': true,
    },
    {
      'icon': Icons.save,
      'title': 'Vorlagen für alles',
      'description': 'Speichere bald auch Belohnungen & Strafen!',
      'comingSoon': true,
    },
  ];
}
