import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';
import 'schriftgroesse_provider.dart';

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
  bool _pawPassAlreadyActivated = false;
  bool _loading = true;
  bool _isPremium = false;
  String? _role;
  DateTime? _premiumEndDate;
  bool _accordionOpen = false;
  bool _changingPlan = false;
  bool _canceling = false;
  String? _currentPlanName;
  int? _currentPlanDays;
  bool _isInFreeTrial = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadFavoriteColor();
    await _loadUserAndPremiumStatus();
    setState(() { _loading = false; });
  }

  Future<void> _loadFavoriteColor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = doc.data()?['favoriteColor'];
    if (name != null && colorMap.containsKey(name)) {
      _favoriteColor = colorMap[name]!;
    }
  }

  Future<void> _loadUserAndPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return;

    final roles = data['roles'];
    if (roles is List && roles.contains('herrchen')) _role = 'herrchen';
    else if (roles is List && roles.contains('doggy')) _role = 'doggy';
    else if (data['doggy'] == true) _role = 'doggy';
    else if (data['herrchen'] == true) _role = 'herrchen';

    final premium = data['premium'] as Map<String, dynamic>?;
    bool isPremium = false;
    DateTime? premiumEnd;
    bool isTrial = false;
    String? planName;
    int? planDays;

    if (_role != null && premium?[_role] == true) {
      isPremium = true;
      if (premium?['expiresAt'] != null) {
        premiumEnd = (premium!['expiresAt'] as Timestamp).toDate();
        if (premium['since'] != null) {
          final since = (premium['since'] as Timestamp).toDate();
          if (premiumEnd.difference(since).inDays <= 31 && data['pawpassActivatedOnce'] == true) {
            isTrial = true;
          }
        }
      }
      if (premium != null && premium['plan'] != null) planName = premium['plan'];
      if (premium != null && premium['planDays'] != null) planDays = premium['planDays'];
    }

    _pawPassAlreadyActivated = data['pawpassActivatedOnce'] == true;
    _isPremium = isPremium;
    _premiumEndDate = premiumEnd;
    _isInFreeTrial = isTrial;
    _currentPlanName = planName;
    _currentPlanDays = planDays;
  }

  Future<void> _requestPremium(String plan, int tage) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_changingPlan) return;
    setState(() { _changingPlan = true; });

    final role = _role;
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rolle nicht erkannt')),
      );
      setState(() { _changingPlan = false; });
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
          SnackBar(content: Text('Planänderung beantragt: $plan')),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anfrage nicht erfolgreich.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
    setState(() { _changingPlan = false; });
  }

  Future<void> _cancelPremium() async {
    if (_canceling) return;
    setState(() { _canceling = true; });
    await Future.delayed(const Duration(seconds: 2));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kündigung wird zum Laufzeitende wirksam.')),
    );
    setState(() { _canceling = false; });
    await _loadAll();
  }

  String _premiumEndInfoText() {
    if (_premiumEndDate == null) return '';
    final end = _premiumEndDate!;
    final dateStr = "${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}";
    if (_isInFreeTrial) {
      return "Dein gratis PawPass läuft noch bis zum $dateStr (4 Wochen). Erst danach kannst du kündigen oder den Plan wechseln.";
    }
    return "Dein aktueller PawPass läuft noch bis zum $dateStr.";
  }

  @override
  Widget build(BuildContext context) {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context);
    final double fontSize = schriftProvider.buttonSchriftgroesse;
    final double horizontalPadding = fontSize * 2.2;
    final double verticalPadding = fontSize * 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('PawPass'),
        actions: [
          IconButton(
            icon: Icon(Icons.star, color: _favoriteColor),
            tooltip: 'Infos zum PawPass',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Row(
                    children: [
                      Icon(Icons.star, color: _favoriteColor),
                      const SizedBox(width: 8),
                      const Text("Was ist PawPass?", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: const Text(
                    "Der PawPass schaltet exklusive Premium-Funktionen für dich und deine Vierbeiner frei. Mit einer aktiven Mitgliedschaft nutzt du alle Vorteile.",
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Schließen"),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(fontSize),
              const SizedBox(height: 16),
              _buildPromoBox(fontSize),
              const SizedBox(height: 24),
              _buildRoleSection(fontSize),
              const SizedBox(height: 18),
              _buildSharedFeatures(fontSize),
              const SizedBox(height: 22),
              if (_isPremium)
                _buildActivePremiumBox(fontSize, horizontalPadding, verticalPadding),
              if (!_isPremium)
                _buildActivateButton(fontSize, horizontalPadding, verticalPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double fontSize) {
    return Row(
      children: [
        Icon(Icons.verified, color: _favoriteColor, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _isPremium
                ? 'Du nutzt bereits PawPass Premium'
                : 'Werde Teil des PawPass-Programms',
            style: TextStyle(
              fontSize: fontSize * 1.22,
              fontWeight: FontWeight.bold,
              color: _favoriteColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromoBox(double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _favoriteColor.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: _favoriteColor.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.card_giftcard, color: _favoriteColor, size: 38),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎁 4 Wochen gratis',
                  style: TextStyle(fontSize: fontSize * 1.03, fontWeight: FontWeight.bold, color: _favoriteColor)),
              Tooltip(
                message: 'Die Gratiswochen werden automatisch an eine normale Mitgliedschaft angehangen.',
                child: Icon(Icons.info_outline, color: _favoriteColor, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Bei deiner ersten PawPass-Aktivierung bekommst du 4 Wochen geschenkt.',
            style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.80),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(double fontSize) {
    final features = _role == 'herrchen' ? herrchenFeatures : doggyFeatures;
    final otherTitle = _role == 'herrchen' ? "Vorteile für Doggys" : "Vorteile für Herrchen";
    final otherFeatures = _role == 'herrchen' ? doggyFeatures : herrchenFeatures;
    return Column(
      children: [
        _buildFeatureCard("Deine PawPass-Vorteile", features, highlight: true, fontSize: fontSize),
        const SizedBox(height: 10),
        _buildAccordion(otherTitle, otherFeatures, fontSize: fontSize),
      ],
    );
  }

  Widget _buildFeatureCard(String title, List<Map<String, dynamic>> features, {bool highlight = false, required double fontSize}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? _favoriteColor.withOpacity(0.10) : const Color(0xFF191919),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _favoriteColor.withOpacity(highlight ? 0.6 : 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: _favoriteColor, size: 19),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _favoriteColor, fontSize: fontSize)),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => _buildFeatureTile(feature, fontSize)),
        ],
      ),
    );
  }

  Widget _buildAccordion(String title, List<Map<String, dynamic>> features, {required double fontSize}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _favoriteColor.withOpacity(0.18), width: 1),
      ),
      child: ExpansionPanelList(
        elevation: 0,
        expandedHeaderPadding: EdgeInsets.zero,
        expansionCallback: (i, expanded) => setState(() => _accordionOpen = !_accordionOpen),
        animationDuration: const Duration(milliseconds: 300),
        children: [
          ExpansionPanel(
            backgroundColor: Colors.transparent,
            canTapOnHeader: true,
            isExpanded: _accordionOpen,
            headerBuilder: (context, isExpanded) => ListTile(
              leading: Icon(Icons.visibility, color: _favoriteColor),
              title: Text(title, style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features.map((feature) => _buildFeatureTile(feature, fontSize)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedFeatures(double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _favoriteColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.handshake, size: 21, color: Colors.grey),
            const SizedBox(width: 7),
            Text('Gemeinsame PawPass-Vorteile',
                style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Beide Seiten benötigen einen aktiven PawPass.',
              child: Icon(Icons.info_outline, color: _favoriteColor, size: 17),
            ),
          ]),
          const SizedBox(height: 12),
          ...gemeinsameFeatures.map((feature) => _buildFeatureTile(feature, fontSize)),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(Map<String, dynamic> feature, double fontSize) {
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
                    Text(feature['title'], style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
                    const SizedBox(height: 2),
                    Text(feature['description'], style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.85)),
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

  Widget _buildActivateButton(double fontSize, double horizontalPadding, double verticalPadding) {
    return OutlinedButton(
      onPressed: _showPlanDialog,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _favoriteColor, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        backgroundColor: Colors.transparent,
      ),
      child: Text(
        'PawPass jetzt aktivieren',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: _favoriteColor,
        ),
      ),
    );
  }

  Widget _buildActivePremiumBox(double fontSize, double horizontalPadding, double verticalPadding) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _favoriteColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _favoriteColor, width: 1.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.verified, color: _favoriteColor),
            const SizedBox(width: 8),
            Text(
              "PawPass aktiv",
              style: TextStyle(fontWeight: FontWeight.bold, color: _favoriteColor, fontSize: fontSize),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9, vertical: verticalPadding),
              ),
              onPressed: () => _showChangeOrCancelDialog(fontSize, horizontalPadding, verticalPadding),
              child: Text('Kündigen/ändern', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: fontSize * 0.95)),
            )
          ]),
          const SizedBox(height: 10),
          Text(
            _premiumEndInfoText(),
            style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.90),
          ),
          if (_isInFreeTrial)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Während der Gratisphase ist keine Kündigung oder Planwechsel möglich.",
                style: TextStyle(color: Colors.redAccent[100], fontSize: fontSize * 0.90),
              ),
            ),
        ],
      ),
    );
  }

  void _showPlanDialog() {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context, listen: false);
    final double fontSize = schriftProvider.buttonSchriftgroesse;
    final double horizontalPadding = fontSize * 2.1;
    final double verticalPadding = fontSize * 0.92;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('PawPass aktivieren', style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption("1 Monat", "2,99 € / Monat", Icons.calendar_view_month, 30, fontSize, horizontalPadding, verticalPadding),
            const SizedBox(height: 12),
            _buildPlanOption("3 Monate", "5,99 € einmalig (1,99 € / Monat)", Icons.calendar_today, 90, fontSize, horizontalPadding, verticalPadding, recommended: true),
            const SizedBox(height: 12),
            _buildPlanOption("12 Monate", "17,99 € einmalig (1,49 € / Monat)", Icons.event_available, 365, fontSize, horizontalPadding, verticalPadding),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Abbrechen", style: TextStyle(fontSize: fontSize * 0.95)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(String title, String price, IconData icon, int tage, double fontSize, double horizontalPadding, double verticalPadding, {bool recommended = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _requestPremium(title, tage);
      },
      child: Container(
        padding: EdgeInsets.all(verticalPadding),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: recommended ? _favoriteColor : Colors.grey, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: _favoriteColor, size: fontSize * 1.2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize)),
                  const SizedBox(height: 4),
                  Text(price, style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.92)),
                ],
              ),
            ),
            if (recommended)
              Container(
                padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: fontSize * 0.17),
                decoration: BoxDecoration(color: _favoriteColor, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Empfohlen',
                  style: TextStyle(color: Colors.white, fontSize: fontSize * 0.7, fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      ),
    );
  }

  void _showChangeOrCancelDialog(double fontSize, double horizontalPadding, double verticalPadding) {
    if (_isInFreeTrial) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF232323),
          title: Text("Noch in der Gratisphase", style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
          content: Text(
            "Während deiner Gratiswochen kannst du den PawPass nicht kündigen oder wechseln. "
            "Du kannst dies erst nach Ablauf der Gratisphase machen.",
            style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.92),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Ok", style: TextStyle(fontSize: fontSize)),
            )
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        title: Text("Kündigen oder Plan ändern?", style: TextStyle(color: _favoriteColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Dein aktueller PawPass läuft noch bis zum "
              "${_premiumEndDate != null ? "${_premiumEndDate!.day.toString().padLeft(2, '0')}.${_premiumEndDate!.month.toString().padLeft(2, '0')}.${_premiumEndDate!.year}" : "-"}.\n\n"
              "Du kannst jetzt kündigen (Abo endet zum Laufzeitende) oder auf einen anderen Zeitraum wechseln. "
              "Ein Planwechsel wird **immer erst nach Ablauf** des aktuellen Zeitraums aktiv.",
              style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.90),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              ),
              label: Text("Kündigen", style: TextStyle(color: Colors.white, fontSize: fontSize)),
              onPressed: _canceling ? null : () async {
                Navigator.pop(ctx);
                await _cancelPremium();
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.loop),
              style: ElevatedButton.styleFrom(
                backgroundColor: _favoriteColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              ),
              label: Text("Plan wechseln", style: TextStyle(color: Colors.white, fontSize: fontSize)),
              onPressed: _changingPlan ? null : () {
                Navigator.pop(ctx);
                _showPlanDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Abbrechen", style: TextStyle(fontSize: fontSize)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
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
      'icon': Icons.star,
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
