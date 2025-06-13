import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class DoggyTaskShopAddButton extends StatelessWidget {
  final List<Map<String, dynamic>> doggys;
  final VoidCallback onTaskAdded;
  final String activeTab;

  const DoggyTaskShopAddButton({
    super.key,
    required this.doggys,
    required this.onTaskAdded,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.brown.shade300,
          icon: const Icon(Icons.add_task_rounded),
          label: Text('$activeTab hinzufügen'),
          onPressed: () => _showTaskDialog(context),
        ),
      ),
    );
  }

  void _showTaskDialog(BuildContext context, {Map<String, dynamic>? task, String? taskId}) {
    showDialog(
      context: context,
      builder: (ctx) => _buildTaskDialog(ctx, task: task, taskId: taskId),
    );
  }

  AlertDialog buildEditDialog(BuildContext context, Map<String, dynamic> task, String taskId) {
    return _buildTaskDialog(context, task: task, taskId: taskId);
  }

  AlertDialog _buildTaskDialog(BuildContext context, {Map<String, dynamic>? task, String? taskId}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?['title'] ?? '');
    final descriptionController = TextEditingController(text: task?['description'] ?? '');
    final pointsController = TextEditingController(text: task?['points']?.toString() ?? '');
    final rewardPriceController = TextEditingController(text: task?['points']?.toString() ?? '');
    final limitValueController = TextEditingController(text: task?['limitValue']?.toString() ?? '');
    final repeatDaysController = TextEditingController();

    DateTime? selectedDate = task?['due'] != null ? DateTime.tryParse(task!['due']) : null;

    TimeOfDay? selectedTime;
    if (task?['dueTime'] != null) {
      final timeParts = (task!['dueTime'] as String).split(':');
      if (timeParts.length == 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
    }

    String repeatType = task?['repeat'] ?? 'einmalig';
    String frequencyLimit = task?['frequencyLimit'] ?? 'beliebig';
    String selectedCategory = task?['category'] ?? activeTab;
    String? selectedDoggyId = task?['doggyId'] ?? (doggys.isNotEmpty ? doggys.first['id'] : null);
    final taskSeriesId = task?['taskSeriesId'] ?? const Uuid().v4();
    String? selectedRewardId = task?['linkedRewardId'];
    String? selectedPunishmentId = task?['linkedPunishmentId'];
    bool visibleToDoggy = task?['visibleToDoggy'] ?? true;
    bool canBePurchased = task?['canBePurchased'] ?? true;

    final List<IconData> availableIcons = [
      Icons.pets,
      Icons.school,
      Icons.shopping_cart,
      Icons.cleaning_services,
      Icons.sports_soccer,
      Icons.emoji_events,
      Icons.local_dining,
      Icons.check_circle,
    ];

    IconData selectedIcon = isEditing && task?['icon'] != null
        ? IconData(task!['icon'], fontFamily: task['iconFontFamily'], fontPackage: task['iconFontPackage'])
        : availableIcons.first;

    return AlertDialog(
      title: Text(isEditing ? 'Eintrag bearbeiten' : 'Eintrag erstellen'),
      content: StatefulBuilder(
        builder: (context, setState) {
          Future<List<Map<String, dynamic>>> loadDropdownData(String collection) async {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .doc(selectedDoggyId)
                .collection(collection)
                .orderBy('createdAt', descending: true)
                .get();
            return snap.docs
                .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
                .toList();
          }

          return FutureBuilder(
            future: Future.wait([
              if (selectedCategory == 'Aufgabe') loadDropdownData('rewards'),
              if (selectedCategory == 'Aufgabe') loadDropdownData('tasks'),
            ]),
            builder: (context, snapshot) {
              final rewards = snapshot.hasData && snapshot.data!.isNotEmpty ? snapshot.data![0] : [];
              final punishments = snapshot.hasData && snapshot.data!.length > 1
                  ? snapshot.data![1].where((t) => t['category'] == 'Bestrafung').toList()
                  : [];

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableIcons.map((icon) => ChoiceChip(
                        label: Icon(icon),
                        selected: selectedIcon == icon,
                        onSelected: (_) => setState(() => selectedIcon = icon),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    DropdownButton<String>(
                      value: selectedDoggyId,
                      isExpanded: true,
                      onChanged: (val) => setState(() => selectedDoggyId = val),
                      items: doggys.map((doggy) => DropdownMenuItem<String>(
                        value: doggy['id'],
                        child: Text(doggy['name'] ?? 'Unbenannt'),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      onChanged: (val) => setState(() => selectedCategory = val!),
                      items: ['Belohnung', 'Bestrafung', 'Aufgabe']
                          .map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat)))
                          .toList(),
                    ),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titel')),
                    TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Beschreibung')),

                    if (selectedCategory == 'Belohnung') ...[
                      TextField(controller: rewardPriceController, decoration: const InputDecoration(labelText: 'Punktepreis'), keyboardType: TextInputType.number),
                      CheckboxListTile(
                        title: const Text('Doggy darf diese Belohnung sehen'),
                        value: visibleToDoggy,
                        onChanged: (val) => setState(() => visibleToDoggy = val ?? true),
                      ),
                      CheckboxListTile(
                        title: const Text('Doggy darf diese Belohnung kaufen'),
                        value: canBePurchased,
                        onChanged: (val) => setState(() => canBePurchased = val ?? true),
                      ),
                    ],

                    if (selectedCategory != 'Belohnung') ...[
                      TextField(controller: pointsController, decoration: const InputDecoration(labelText: 'Punkte'), keyboardType: TextInputType.number),

                      if (selectedCategory == 'Aufgabe') ...[
                        DropdownButton<String>(
                          value: rewards.any((r) => r['id'] == selectedRewardId) ? selectedRewardId : null,
                          hint: const Text('Optionale Belohnung auswählen'),
                          isExpanded: true,
                          onChanged: (val) => setState(() => selectedRewardId = val),
                          items: rewards.map((r) =>
                              DropdownMenuItem<String>(value: r['id'], child: Text(r['title'] ?? 'Belohnung'))).toList(),
                        ),
                        DropdownButton<String>(
                          value: punishments.any((p) => p['id'] == selectedPunishmentId) ? selectedPunishmentId : null,
                          hint: const Text('Optionale Bestrafung auswählen'),
                          isExpanded: true,
                          onChanged: (val) => setState(() => selectedPunishmentId = val),
                          items: punishments.map((p) =>
                              DropdownMenuItem<String>(value: p['id'], child: Text(p['title'] ?? 'Bestrafung'))).toList(),
                        ),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                selectedDate != null
                                    ? 'Fällig: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}'
                                    : 'Kein Datum gewählt'
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                locale: const Locale('de', 'DE'),
                              );
                              if (picked != null) setState(() => selectedDate = picked);
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedTime != null
                                  ? 'Bis: ${selectedTime!.format(context)}'
                                  : 'Keine Uhrzeit gewählt',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) setState(() => selectedTime = picked);
                            },
                          ),
                        ],
                      ),
                      DropdownButton<String>(
                        value: repeatType,
                        isExpanded: true,
                        onChanged: (value) => setState(() => repeatType = value!),
                        items: const [
                          DropdownMenuItem(value: 'einmalig', child: Text('Einmalig')),
                          DropdownMenuItem(value: 'weekly', child: Text('Wöchentlich')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monatlich')),
                          DropdownMenuItem(value: 'every_x', child: Text('Alle X Tage')),
                        ],
                      ),
                      if (repeatType == 'every_x')
                        TextField(controller: repeatDaysController, decoration: const InputDecoration(labelText: 'Alle wie viele Tage?'), keyboardType: TextInputType.number),
                      DropdownButton<String>(
                        value: frequencyLimit,
                        isExpanded: true,
                        onChanged: (value) => setState(() => frequencyLimit = value!),
                        items: const [
                          DropdownMenuItem(value: 'beliebig', child: Text('Beliebig oft')),
                          DropdownMenuItem(value: 'mindestens', child: Text('Mindestens')),
                          DropdownMenuItem(value: 'höchstens', child: Text('Höchstens')),
                        ],
                      ),
                      if (frequencyLimit != 'beliebig')
                        TextField(controller: limitValueController, decoration: const InputDecoration(labelText: 'Limit pro Tag'), keyboardType: TextInputType.number),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null || titleController.text.trim().isEmpty) return;

            final dueTime = selectedTime != null
                ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                : null;

            final data = {
              'title': titleController.text.trim(),
              'description': descriptionController.text.trim(),
              'icon': selectedIcon.codePoint,
              'iconFontFamily': selectedIcon.fontFamily,
              'iconFontPackage': selectedIcon.fontPackage,
              'createdBy': user.uid,
              'category': selectedCategory,
              'createdAt': FieldValue.serverTimestamp(),
            };

            if (selectedCategory == 'Belohnung') {
              data.addAll({
                'points': int.tryParse(rewardPriceController.text.trim()) ?? 0,
                'visibleToDoggy': visibleToDoggy,
                'canBePurchased': canBePurchased,
                'assignedAsReward': false,
              });

              final ref = FirebaseFirestore.instance
                  .collection('users')
                  .doc(selectedDoggyId)
                  .collection('rewards');

              if (isEditing && taskId != null) {
                await ref.doc(taskId).update(data);
              } else {
                await ref.add(data);
              }
            } else {
              data.addAll({
                'points': int.tryParse(pointsController.text.trim()) ?? 0,
                'due': selectedDate?.toIso8601String(),
                'dueTime': dueTime,
                'repeat': repeatType,
                'frequencyLimit': frequencyLimit,
                'limitValue': limitValueController.text.trim(),
                'taskSeriesId': repeatType != 'einmalig' ? taskSeriesId : null,
                'isSeriesInstance': repeatType != 'einmalig',
                'linkedRewardId': selectedRewardId,
                'linkedPunishmentId': selectedPunishmentId,
              });

              final ref = FirebaseFirestore.instance
                  .collection('users')
                  .doc(selectedDoggyId)
                  .collection('tasks');

              if (isEditing && taskId != null) {
                await ref.doc(taskId).update(data);
              } else {
                await ref.add(data);
              }
            }

            Navigator.pop(context);
            onTaskAdded();
          },
          child: Text(isEditing ? 'Aktualisieren' : 'Hinzufügen'),
        ),
      ],
    );
  }
}