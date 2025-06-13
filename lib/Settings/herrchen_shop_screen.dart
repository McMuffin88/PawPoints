import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pawpoints/doggyaufgabenform.dart';

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

    final String collectionPath = category == 'Belohnung' ? 'rewards' : 'tasks';

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

        final tasks = snapshot.data!.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['category'] == category)
            .toList();


        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final doc = tasks[index];
            final task = doc.data() as Map<String, dynamic>;
            final description = task['description'] ?? '';
            final iconData = task['icon'] != null
                ? IconData(task['icon'], fontFamily: task['iconFontFamily'], fontPackage: task['iconFontPackage'])
                : Icons.task_alt;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(iconData),
                title: Text(task['title'] ?? 'Ohne Titel'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) Text(description),
                    if (task['points'] != null)
                      Text(category == 'Belohnung'
                          ? 'Kosten: ${task['points']} Punkte'
                          : 'Punkte: ${task['points']}'),
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
                        ).buildEditDialog(context, task, doc.id),
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
              children: [
                _buildTaskList('Aufgabe'),
                _buildTaskList('Belohnung'),
                _buildTaskList('Bestrafung'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: DoggyTaskShopAddButton(
        doggys: _doggys,
        onTaskAdded: _loadDoggys,
        activeTab: ['Aufgabe', 'Belohnung', 'Bestrafung'][_selectedTabIndex],
      ),
    );
  }
}
