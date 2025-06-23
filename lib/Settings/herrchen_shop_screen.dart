import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pawpoints/doggyaufgabenform.dart';

// ICON-MAP OBEN EINMALIG DEFINIEREN
final Map<String, IconData> iconMap = {
  'star': Icons.star,
  'favorite': Icons.favorite,
  'home': Icons.home,
  'pets': Icons.pets,
  'check': Icons.check,
  'shopping_cart': Icons.shopping_cart,
  'reward': Icons.card_giftcard,
  // beliebig erweitern
};

class HerrchenShopScreen extends StatefulWidget {
  const HerrchenShopScreen({super.key});

  @override
  State<HerrchenShopScreen> createState() => _HerrchenShopScreenState();
}

class _HerrchenShopScreenState extends State<HerrchenShopScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _doggys = [];
  String? _selectedDoggy;
  TabController? _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController!.index;
      });
    });
    _loadDoggys();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadDoggys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('doggys')
        .get();

    final doggys = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    setState(() {
      _doggys = doggys;
      if (_doggys.isNotEmpty) {
        _selectedDoggy = _doggys.first['id'];
      }
    });
  }

  Widget _buildTaskList(String category) {
    if (_selectedDoggy == null) {
      return const Center(child: Text('Kein Doggy ausgewählt.'));
    }

    // Abhängig vom Tab die richtige Collection wählen:
    final String collectionPath = category == 'Belohnung'
        ? 'rewards'
        : category == 'Bestrafung'
        ? 'revenge'
        : 'tasks';

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(_selectedDoggy!)
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Keine Einträge gefunden.'));
        }

        // Bei tasks und rewards auf category filtern, bei revenge liegt keine category vor
        final items = snapshot.data!.docs.where((doc) {
          if (collectionPath == 'revenge') return true;
          final data = doc.data() as Map<String, dynamic>;
          return data['category'] == category;
        }).toList();

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            final task = doc.data() as Map<String, dynamic>;
            final description = task['description'] ?? '';

            // HIER ICONAUSWAHL BEREINIGT!
            final String? iconKey = task['icon'];
            final IconData icon = iconKey != null && iconMap.containsKey(iconKey)
                ? iconMap[iconKey]!
                : Icons.task_alt;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(icon),
                title: Text(task['title'] ?? 'Ohne Titel'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(
                            text: category == 'Belohnung'
                                ? 'Beschreibung: '
                                : category == 'Bestrafung'
                                    ? 'Grund: '
                                    : 'Aufgabe: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: description,
                                style: const TextStyle(fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (category == 'Aufgabe' && task['linkedRewardId'] != null)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_selectedDoggy)
                            .collection('rewards')
                            .doc(task['linkedRewardId'])
                            .get(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Text('🎁 Belohnung: lädt...');
                          }
                          if (snap.hasData && snap.data!.exists) {
                            final reward = snap.data!.data() as Map<String, dynamic>;
                            return Text('🎁 Belohnung: ${reward['title']}');
                          }
                          return const Text('🎁 Belohnung: [nicht gefunden]');
                        },
                      ),
                    if (category == 'Aufgabe' &&
                        task['linkedPunishmentId'] != null)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_selectedDoggy)
                            .collection('revenge')
                            .doc(task['linkedPunishmentId'])
                            .get(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Text('⚠️ Bestrafung: lädt...');
                          }
                          if (snap.hasData && snap.data!.exists) {
                            final punishment = snap.data!.data() as Map<String, dynamic>;
                            return Text('⚠️ Bestrafung: ${punishment['title']}');
                          }
                          return const Text('⚠️ Bestrafung: [nicht gefunden]');
                        },
                      ),
                    const Divider(),
                    if (task['points'] != null)
                      Text(
                        collectionPath == 'rewards'
                            ? 'Kosten: ${task['points']} Punkte'
                            : 'Punkte: ${task['points']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_selectedDoggy)
                          .collection(collectionPath)
                          .doc(doc.id)
                          .delete();
                    } else if (value == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => DoggyTaskShopAddButton(
                          doggys: _doggys,
                          onTaskAdded: _loadDoggys,
                          activeTab: category,
                        ).buildEditDialog(
                          context,
                          {
                            ...task,
                            'doggyId': _selectedDoggy,
                          },
                          doc.id,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDoggySelector() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _doggys.length,
        itemBuilder: (context, index) {
          final doggy = _doggys[index];
          final selected = doggy['id'] == _selectedDoggy;

          return GestureDetector(
            onTap: () => setState(() => _selectedDoggy = doggy['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? Colors.blue : Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
              ),
              width: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: doggy['profileImageUrl'] != null
                        ? NetworkImage(doggy['profileImageUrl'])
                        : null,
                    radius: 25,
                    child: doggy['profileImageUrl'] == null
                        ? const Icon(Icons.pets)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(doggy['name'] ?? 'Unbenannt', textAlign: TextAlign.center),
                  if (doggy['age'] != null) Text('Alter: ${doggy['age']}'),
                  if (doggy['level'] != null) Text('Level: ${doggy['level']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Aufgabe', 'Belohnung', 'Bestrafung'];

    return Scaffold(
      appBar: AppBar(title: const Text('Shop-Verwaltung')),
      body: _doggys.isEmpty
          ? const Center(child: Text('Keine verbundenen Doggys gefunden.'))
          : Column(
              children: [
                const SizedBox(height: 8),
                _buildDoggySelector(),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  onTap: (index) => setState(() => _selectedTabIndex = index),
                  tabs: const [
                    Tab(text: 'Aufgaben'),
                    Tab(text: 'Belohnungen'),
                    Tab(text: 'Bestrafungen'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: tabs.map((tab) => _buildTaskList(tab)).toList(),
                  ),
                ),
              ],
            ),
      floatingActionButton: DoggyTaskShopAddButton(
        doggys: _doggys,
        onTaskAdded: _loadDoggys,
        activeTab: tabs[_selectedTabIndex],
      ),
    );
  }
}
