import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/Settings/schriftgroesse_provider.dart';
import 'package:uuid/uuid.dart';

final Map<String, IconData> iconMap = {
  'pets': Icons.pets,
  'school': Icons.school,
  'shopping_cart': Icons.shopping_cart,
  'cleaning_services': Icons.cleaning_services,
  'sports_soccer': Icons.sports_soccer,
  'emoji_events': Icons.emoji_events,
  'local_dining': Icons.local_dining,
  'check_circle': Icons.check_circle,
};

final List<String> availableIconKeys = [
  'pets',
  'school',
  'shopping_cart',
  'cleaning_services',
  'sports_soccer',
  'emoji_events',
  'local_dining',
  'check_circle',
];

class TaskData {
  String title = '';
  String description = '';
  int points = 0;
  String frequency = 'einmalig';
  DateTime? dueDate;
  TimeOfDay? dueTime;
  String? repeatType;
  int? repeatDays;
  String frequencyLimit = 'beliebig';
  int? limitValue;
  List<String> assignedDoggyIds = [];
  String iconKey = availableIconKeys.first;
  String? linkedRewardId;
  String? linkedPunishmentId;
  String taskSeriesId = const Uuid().v4();

  String taskType = 'Aufgabe';

  void reset() {
    title = '';
    description = '';
    points = 0;
    frequency = 'einmalig';
    dueDate = null;
    dueTime = null;
    repeatType = null;
    repeatDays = null;
    frequencyLimit = 'beliebig';
    limitValue = null;
    assignedDoggyIds = [];
    iconKey = availableIconKeys.first;
    linkedRewardId = null;
    linkedPunishmentId = null;
    taskSeriesId = const Uuid().v4();
    taskType = 'Aufgabe';
  }
}

class DoggyTaskCreationDialog extends StatefulWidget {
  final String? userFavoriteColorName;
  final String herrchenId;
  final VoidCallback onTaskAdded;

  const DoggyTaskCreationDialog({
    super.key,
    this.userFavoriteColorName,
    required this.herrchenId,
    required this.onTaskAdded,
  });

  @override
  State<DoggyTaskCreationDialog> createState() => _DoggyTaskCreationDialogState();
}

class _DoggyTaskCreationDialogState extends State<DoggyTaskCreationDialog> {
  int _currentStep = 0;
  final TaskData _taskData = TaskData();
  final _formKeys = List.generate(4, (index) => GlobalKey<FormState>());
  List<Map<String, dynamic>> _doggys = [];
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _repeatDaysController = TextEditingController();
  final TextEditingController _limitValueController = TextEditingController();

  List<Map<String, dynamic>> _loadedRewards = [];
  List<Map<String, dynamic>> _loadedPunishments = [];

  DateTime? _repeatStartDate;
  DateTime? _monthlySelectedDate;

  bool? _isPremium;
  bool _loadingPremium = true;

  bool _isSubmitting = false;

String _getLinkedItemTitle(String? itemId, List<Map<String, dynamic>> loadedItems, {required bool isReward}) {
  if (itemId == null) {
    return isReward ? 'Keine vorgefertigte Belohnung gewählt' : 'Keine vorgefertigte Bestrafung gewählt';
  }
  final item = loadedItems.firstWhere(
    (i) => i['id'] == itemId,
    orElse: () => {'title': 'Unbekannt (ID: $itemId)'},
  );
  return item['title'];
}



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

  Color get favoriteColor {
    final colorName = widget.userFavoriteColorName;
    return (colorName != null && colorMap.containsKey(colorName))
        ? colorMap[colorName]!
        : Colors.brown;
  }

  @override
  void initState() {
    super.initState();
    _loadDoggys();
    _pointsController.text = _taskData.points.toString();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    setState(() {
      _loadingPremium = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkHerrchenPremiumStatus');
      final result = await callable();
      final bool isPremium = result.data['isPremium'] ?? false;
      setState(() {
        _isPremium = isPremium;
        _loadingPremium = false;
      });
    } catch (e) {
      print('Fehler bei Premium-Abfrage: $e');
      setState(() {
        _isPremium = false;
        _loadingPremium = false;
      });
    }
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _repeatDaysController.dispose();
    _limitValueController.dispose();
    super.dispose();
  }

  Future<void> _loadDoggys() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doggysSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('doggys')
        .get();
    final List<Map<String, dynamic>> loaded = [];
    for (var doc in doggysSnap.docs) {
      loaded.add({
        'id': doc.id,
        'benutzername': doc.data()['benutzername'],
        'profileImageUrl': doc.data()['profileImageUrl'],
      });
    }
    if (mounted) {
      setState(() {
        _doggys = loaded;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadDropdownData(String collection) async {
    if (_taskData.assignedDoggyIds.isEmpty) return [];
    final doggyIdToLoadFrom = _taskData.assignedDoggyIds.first;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(doggyIdToLoadFrom)
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .get();
    final loadedItems = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

    if (collection == 'rewards') {
      _loadedRewards = loadedItems;
    } else if (collection == 'revenge') {
      _loadedPunishments = loadedItems;
    }
    return loadedItems;
  }

  void _nextStep() {
    bool valid = _formKeys[_currentStep].currentState?.validate() ?? true; // Validierung der Formulare

    if (valid) {
      _formKeys[_currentStep].currentState?.save();

      if (_currentStep == 0 && _taskData.assignedDoggyIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte wähle mindestens einen Doggy aus.')),
        );
        return;
      }

      // Neue Bedingung: Step 2 - mindestens eine Belohnung (verknüpft oder manuell) muss ausgewählt sein
      if (_currentStep == 2) {
        if (_taskData.linkedRewardId == null && _manualRewards.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bitte wähle eine Belohnung aus oder füge manuelle Punkte hinzu.')),
          );
          return;
        }
      }

      if (_currentStep == 2 && _taskData.assignedDoggyIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte weisen Sie die Aufgabe mindestens einem Doggy zu.')),
        );
        return;
      }

      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitTask();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte alle Pflichtfelder ausfüllen.')),
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

Future<void> _submitTask() async {
  // Punkte aus manuellen Belohnungen summieren
    setState(() {
    _isSubmitting = true;
  });
  final int manualPointsSum = _manualRewards.fold(0, (sum, reward) => sum + (reward['points'] as int? ?? 0));
  final int totalPoints = _taskData.points + manualPointsSum;

  if (_taskData.title.isEmpty || _taskData.assignedDoggyIds.isEmpty || 
      (_taskData.linkedRewardId == null && _manualRewards.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bitte füllen Sie alle erforderlichen Felder aus und wählen Sie mindestens eine Belohnung aus.')),
    );
    return;
  }

  if (totalPoints <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bitte geben Sie mindestens 1 Punkt an (entweder in Hauptpunkten oder in manuellen Belohnungen).')),
    );
    return;
  }
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('createDoggyTask');
    final taskDataToSend = {
      'herrchenId': widget.herrchenId,
      'title': _taskData.title,
      'description': _taskData.description.isNotEmpty ? _taskData.description : null,
      'points': totalPoints,
      'frequency': _taskData.frequency,
      'dueDate': _taskData.dueDate?.toIso8601String(),
      'dueTime': _taskData.dueTime != null
          ? '${_taskData.dueTime!.hour.toString().padLeft(2, '0')}:${_taskData.dueTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'repeatType': _taskData.repeatType,
      'repeatDays': _taskData.repeatDays,
      'repeatStartDate': _repeatStartDate?.toIso8601String(),
      'frequencyLimit': _taskData.frequencyLimit,
      'limitValue': _taskData.limitValue,
      'assignedDoggyIds': _taskData.assignedDoggyIds,
      'icon': _taskData.iconKey,
      'linkedRewardId': _taskData.linkedRewardId,
      'linkedPunishmentId': _taskData.linkedPunishmentId,
      'taskSeriesId': _taskData.taskSeriesId,
      'isSeriesInstance': _taskData.repeatType != 'einmalig',
      'taskType': _taskData.taskType,
    };
    final result = await callable.call(taskDataToSend);
    if (mounted) {
      if (result.data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aufgabe "${_taskData.title}" erfolgreich erstellt!')),
        );
        widget.onTaskAdded();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Erstellen der Aufgabe: ${result.data['message']}')),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ein unerwarteter Fehler ist aufgetreten: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

  Widget _buildStepContent(int step) {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context, listen: false);
    switch (step) {
      case 0:
        return _buildStepDetails(schriftProvider);
      case 1:
        return _buildStepPointsFrequency(schriftProvider);
      case 2:
        return _buildStepAssignmentLinking(schriftProvider);
      case 3:
        return _buildStepSummary(schriftProvider);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepDetails(SchriftgroesseProvider schriftProvider) {
    final iconsToShow = (_isPremium == true) ? availableIconKeys : ['pets'];

    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aufgabe / Challenge Auswahl mit Premium-Check
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Aufgabe'),
                  selected: _taskData.taskType == 'Aufgabe',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _taskData.taskType = 'Aufgabe';
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
                _isPremium == true
                    ? ChoiceChip(
                        label: const Text('Challenge'),
                        selected: _taskData.taskType == 'Challenge',
                        selectedColor: favoriteColor,
                        labelStyle: TextStyle(
                          color: _taskData.taskType == 'Challenge' ? Colors.white : Colors.grey[600],
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            if (_taskData.assignedDoggyIds.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Für eine Challenge müssen mindestens zwei Doggys ausgewählt sein.'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _taskData.taskType = 'Challenge';
                            });
                          }
                        },
                      )
                    : GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/premium_screen');
                        },
                        child: Opacity(
                          opacity: 0.5,
                          child: Chip(
                            avatar: const Icon(Icons.lock, size: 18, color: Colors.grey),
                            label: Text(
                              'Challenge',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
              ],
            ),

            const SizedBox(height: 16),

            // Doggy-Auswahl mittig zentriert
            Center(
              child: FormField<List<String>>(
                initialValue: _taskData.assignedDoggyIds,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte wähle mindestens einen Doggy aus';
                  }
                  return null;
                },
                builder: (state) {
                  return Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: _doggys.map((doggy) {
                          final isSelected = _taskData.assignedDoggyIds.contains(doggy['id']);
                          return FilterChip(
                            label: Text(
                              doggy['benutzername'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                                fontSize: schriftProvider.allgemeineSchriftgroesse,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: favoriteColor,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _taskData.assignedDoggyIds.add(doggy['id']);
                                } else {
                                  _taskData.assignedDoggyIds.remove(doggy['id']);
                                }
                                // Trigger FormField validation update
                                state.didChange(_taskData.assignedDoggyIds);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            state.errorText ?? '',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Aufgabentitel',
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9,
                color: Colors.grey[400],
              ),
            ),
            TextFormField(
              initialValue: _taskData.title,
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Z.B. "Spaziergang"',
                hintStyle: TextStyle(
                  fontSize: schriftProvider.allgemeineSchriftgroesse,
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Titel darf nicht leer sein';
                return null;
              },
              onSaved: (value) => _taskData.title = value!,
            ),

            const SizedBox(height: 16),

            Text(
              'Beschreibung (optional)',
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9,
                color: Colors.grey[400],
              ),
            ),
            TextFormField(
              initialValue: _taskData.description,
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse,
                color: Colors.white,
              ),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Detaillierte Anweisungen',
                hintStyle: TextStyle(
                  fontSize: schriftProvider.allgemeineSchriftgroesse,
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              onSaved: (value) => _taskData.description = value!,
            ),

            const SizedBox(height: 16),

            Text(
              'Icon auswählen',
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: (_isPremium == true)
                    ? availableIconKeys.map((key) => _buildIconChoice(key, schriftProvider)).toList()
                    : [_buildIconChoice('pets', schriftProvider)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconChoice(String key, SchriftgroesseProvider schriftProvider) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _taskData.iconKey = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: _taskData.iconKey == key ? favoriteColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: _taskData.iconKey == key ? favoriteColor : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Icon(
          iconMap[key],
          color: _taskData.iconKey == key ? Colors.white : Colors.grey[400],
          size: schriftProvider.allgemeineSchriftgroesse * 1.5,
        ),
      ),
    );
  }

  Widget _buildStepPointsFrequency(SchriftgroesseProvider schriftProvider) {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frequenz', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
            DropdownButtonFormField<String>(
              value: _taskData.frequency,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              dropdownColor: Colors.grey[850],
              style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
              iconEnabledColor: Colors.white,
              items: <String>['einmalig', 'täglich', 'wöchentlich', 'monatlich', 'alle x Tage']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _taskData.frequency = newValue!;
                  if (newValue == 'einmalig') {
                    _taskData.repeatType = null;
                    _taskData.repeatDays = null;
                    _taskData.dueDate = null;
                    _taskData.dueTime = null;
                  } else if (newValue == 'täglich') {
                    _taskData.repeatType = 'daily';
                    _taskData.repeatDays = null;
                  } else if (newValue == 'wöchentlich') {
                    _taskData.repeatType = 'weekly';
                    _taskData.repeatDays = null;
                  } else if (newValue == 'monatlich') {
                    _taskData.repeatType = 'monthly';
                    _taskData.repeatDays = null;
                  } else if (newValue == 'alle x Tage') {
                    _taskData.repeatType = 'every_days';
                  }
                });
              },
            ),
            if (_taskData.frequency == 'einmalig') ...[
              const SizedBox(height: 16),
              Text('Fälligkeitsdatum (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _taskData.dueDate == null
                      ? 'Datum auswählen'
                      : DateFormat('dd.MM.yyyy').format(_taskData.dueDate!),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _taskData.dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _taskData.dueDate) {
                    setState(() {
                      _taskData.dueDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('Fälligkeitszeit (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _taskData.dueTime == null
                      ? 'Zeit auswählen'
                      : _taskData.dueTime!.format(context),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.access_time, color: Colors.white),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _taskData.dueTime ?? TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _taskData.dueTime) {
                    setState(() {
                      _taskData.dueTime = picked;
                    });
                  }
                },
              ),
            ],
            if (_taskData.frequency == 'wöchentlich') ...[
              const SizedBox(height: 16),
              Text('Wochentag auswählen (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              DropdownButtonFormField<int>(
                value: _taskData.repeatDays,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                dropdownColor: Colors.grey[850],
                style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                iconEnabledColor: Colors.white,
                items: List.generate(7, (index) {
                  final weekdayNames = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
                  return DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(weekdayNames[index]),
                  );
                }),
                onChanged: (int? newValue) {
                  setState(() {
                    _taskData.repeatDays = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Fälligkeitszeit (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _taskData.dueTime == null
                      ? 'Zeit auswählen'
                      : _taskData.dueTime!.format(context),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.access_time, color: Colors.white),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _taskData.dueTime ?? TimeOfDay(hour: 23, minute: 59),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _taskData.dueTime) {
                    setState(() {
                      _taskData.dueTime = picked;
                    });
                  }
                },
              ),
            ],
            if (_taskData.frequency == 'monatlich') ...[
              const SizedBox(height: 16),
              Text('Datum auswählen (aktueller Monat)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _monthlySelectedDate == null
                      ? 'Kein Datum gewählt'
                      : DateFormat('dd.MM.yyyy').format(_monthlySelectedDate!),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white),
                onTap: () async {
                  final DateTime now = DateTime.now();
                  final DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
                  final DateTime lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _monthlySelectedDate ?? firstDayOfMonth,
                    firstDate: firstDayOfMonth,
                    lastDate: lastDayOfMonth,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _monthlySelectedDate = picked;
                      _taskData.repeatDays = picked.day;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('Fälligkeitszeit (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _taskData.dueTime == null
                      ? 'Zeit auswählen'
                      : _taskData.dueTime!.format(context),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.access_time, color: Colors.white),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _taskData.dueTime ?? TimeOfDay(hour: 23, minute: 59),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _taskData.dueTime) {
                    setState(() {
                      _taskData.dueTime = picked;
                    });
                  }
                },
              ),
            ],
            if (_taskData.frequency == 'alle x Tage') ...[
              const SizedBox(height: 16),
              Text('Wiederholen alle (Tage)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              TextFormField(
                controller: _repeatDaysController,
                style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Z.B. 7 (für jede Woche)',
                  hintStyle: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie eine Zahl an';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Bitte geben Sie eine positive Zahl ein';
                  }
                  return null;
                },
                onSaved: (value) => _taskData.repeatDays = int.parse(value!),
              ),
              const SizedBox(height: 16),
              Text('Startdatum (optional)', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              ListTile(
                title: Text(
                  _repeatStartDate == null
                      ? 'Datum auswählen'
                      : DateFormat('dd.MM.yyyy').format(_repeatStartDate!),
                  style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _repeatStartDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: favoriteColor,
                            onPrimary: Colors.white,
                            surface: Colors.grey[800]!,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: Colors.grey[900],
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && picked != _repeatStartDate) {
                    setState(() {
                      _repeatStartDate = picked;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Text('Häufigkeitsbegrenzung', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
            DropdownButtonFormField<String>(
              value: _taskData.frequencyLimit,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              dropdownColor: Colors.grey[850],
              style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
              iconEnabledColor: Colors.white,
              items: <String>['beliebig', 'mindestens', 'höchstens']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _taskData.frequencyLimit = newValue!;
                  if (newValue == 'beliebig') {
                    _taskData.limitValue = null;
                  }
                });
              },
            ),
            if (_taskData.frequencyLimit != 'beliebig') ...[
              const SizedBox(height: 16),
              Text('Anzahl der Ausführungen', style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.grey[400])),
              TextFormField(
                controller: _limitValueController,
                style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Z.B. 3',
                  hintStyle: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse, color: Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Wert darf nicht leer sein';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Bitte geben Sie eine positive Zahl ein';
                  }
                  return null;
                },
                onSaved: (value) => _taskData.limitValue = int.parse(value!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _manualRewards = [];
  final TextEditingController _manualRewardPointsController = TextEditingController();

  List<Map<String, dynamic>> _manualPunishments = [];
  final TextEditingController _manualPunishmentPointsController = TextEditingController();

  Widget _buildStepAssignmentLinking(SchriftgroesseProvider schriftProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Belohnungen Titel und Auswahl
          Text(
            'Belohnungen',
            style: TextStyle(
              fontSize: schriftProvider.allgemeineSchriftgroesse * 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          // Vorhandene Belohnungen Dropdown
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadDropdownData('rewards'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Fehler beim Laden der Belohnungen: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final rewards = snapshot.data ?? [];
              return DropdownButtonFormField<String>(
                value: _taskData.linkedRewardId,
                decoration: InputDecoration(
                  hintText: rewards.isEmpty ? 'Keine Belohnungen verfügbar' : 'Belohnung auswählen',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                isExpanded: true,
                items: rewards.map<DropdownMenuItem<String>>((reward) {
                  return DropdownMenuItem<String>(
                    value: reward['id'],
                    child: Text(reward['title'], overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: rewards.isEmpty
                    ? null
                    : (String? newValue) {
                        setState(() {
                          _taskData.linkedRewardId = newValue;
                        });
                      },
              );
            },
          ),
          const SizedBox(height: 16),
          // Manuelle Belohnungen hinzufügen
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _manualRewardPointsController,
                  style: TextStyle(color: Colors.white, fontSize: schriftProvider.allgemeineSchriftgroesse),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Manuelle Punkte hinzufügen',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _manualRewardPointsController.text.trim();
                  final points = int.tryParse(text);
                  if (points == null || points <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bitte eine positive Zahl für manuelle Punkte eingeben.')),
                    );
                    return;
                  }
                  setState(() {
                    _manualRewards.add({
                      'id': UniqueKey().toString(),
                      'title': 'Manuelle Punkte',
                      'points': points,
                    });
                    _manualRewardPointsController.clear();
                  });
                },
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Liste der manuellen Belohnungen
          if (_manualRewards.isNotEmpty) ...[
            Text(
              'Manuelle Belohnungen',
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse * 1.0,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            ..._manualRewards.map((reward) {
              return Card(
                color: Colors.lightBlue[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('Erhalte ${reward['points']} Punkt(e) jedes Mal.',
                      style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _manualRewards.removeWhere((r) => r['id'] == reward['id']);
                      });
                    },
                  ),
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 24),

          // Bestrafungen Titel und Auswahl
          Text(
            'Bestrafungen',
            style: TextStyle(
              fontSize: schriftProvider.allgemeineSchriftgroesse * 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          // Vorhandene Bestrafungen Dropdown
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadDropdownData('revenge'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Fehler beim Laden der Bestrafungen: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final punishments = snapshot.data ?? [];
              return DropdownButtonFormField<String>(
                value: _taskData.linkedPunishmentId,
                decoration: InputDecoration(
                  hintText: punishments.isEmpty ? 'Keine Bestrafungen verfügbar' : 'Bestrafung auswählen',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                isExpanded: true,
                items: punishments.map<DropdownMenuItem<String>>((punishment) {
                  return DropdownMenuItem<String>(
                    value: punishment['id'],
                    child: Text(punishment['title'], overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: punishments.isEmpty
                    ? null
                    : (String? newValue) {
                        setState(() {
                          _taskData.linkedPunishmentId = newValue;
                        });
                      },
              );
            },
          ),
          const SizedBox(height: 16),
          // Manuelle Bestrafungen hinzufügen
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _manualPunishmentPointsController,
                  style: TextStyle(color: Colors.white, fontSize: schriftProvider.allgemeineSchriftgroesse),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Punkte-Abzug hinzufügen',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _manualPunishmentPointsController.text.trim();
                  final points = int.tryParse(text);
                  if (points == null || points <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bitte eine positive Zahl für manuelle Bestrafung eingeben.')),
                    );
                    return;
                  }
                  setState(() {
                    _manualPunishments.add({
                      'id': UniqueKey().toString(),
                      'title': 'Manuelle Bestrafung',
                      'points': points,
                    });
                    _manualPunishmentPointsController.clear();
                  });
                },
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Liste der manuellen Bestrafungen
          if (_manualPunishments.isNotEmpty) ...[
            Text(
              'Manuelle Bestrafungen',
              style: TextStyle(
                fontSize: schriftProvider.allgemeineSchriftgroesse * 1.0,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            ..._manualPunishments.map((punishment) {
              return Card(
                color: Colors.red[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('Zieht bei Nichterfüllung ${punishment['points']} Punkte ab.',
                      style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _manualPunishments.removeWhere((p) => p['id'] == punishment['id']);
                      });
                    },
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildStepSummary(SchriftgroesseProvider schriftProvider) {
  String assignedDoggys = _taskData.assignedDoggyIds.isNotEmpty
      ? _taskData.assignedDoggyIds
          .map((id) =>
              _doggys.firstWhere((d) => d['id'] == id, orElse: () => {'benutzername': 'Unbekannt'})['benutzername'])
          .join(', ')
      : 'Keine Zuordnung';

  String rewardTitle = _getLinkedItemTitle(_taskData.linkedRewardId, _loadedRewards, isReward: true);
  String punishmentTitle = _getLinkedItemTitle(_taskData.linkedPunishmentId, _loadedPunishments, isReward: false);

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Überschrift mit Icon und Titel
            Row(
              children: [
                Icon(iconMap[_taskData.iconKey] ?? Icons.help_outline, size: 32, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _taskData.title.isNotEmpty ? _taskData.title : 'Kein Titel',
                    style: TextStyle(
                      fontSize: schriftProvider.allgemeineSchriftgroesse * 1.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _taskData.taskType,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _taskData.taskType == 'Challenge' ? Colors.orange : Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_taskData.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Beschreibung: ${_taskData.description}',
                  style: TextStyle(color: Colors.grey[300], fontSize: schriftProvider.allgemeineSchriftgroesse),
                ),
              ),

            Divider(color: Colors.grey[700]),

            _infoRow(Icons.pets, 'Zugewiesen an:', assignedDoggys, schriftProvider),
            _infoRow(Icons.repeat, 'Frequenz:', _taskData.frequency, schriftProvider),

            if (_taskData.frequency == 'einmalig' && _taskData.dueDate != null)
              _infoRow(Icons.calendar_today, 'Fälligkeitsdatum:', DateFormat('dd.MM.yyyy').format(_taskData.dueDate!), schriftProvider),

            if (_taskData.frequency == 'einmalig' && _taskData.dueTime != null)
              _infoRow(Icons.access_time, 'Fälligkeitszeit:', _taskData.dueTime!.format(context), schriftProvider),

            if (_taskData.frequency == 'alle x Tage' && _taskData.repeatDays != null)
              _infoRow(Icons.cached, 'Alle x Tage:', '${_taskData.repeatDays} Tage', schriftProvider),

            _infoRow(Icons.trending_up, 'Häufigkeitsbegrenzung:', _taskData.frequencyLimit == 'beliebig' ? 'Beliebig' : '${_taskData.frequencyLimit} ${_taskData.limitValue ?? ''} mal', schriftProvider),

            const SizedBox(height: 16),
            Divider(color: Colors.grey[700]),

            // Verknüpfte Belohnung
            _infoRow(Icons.emoji_events, 'Belohnung:', rewardTitle, schriftProvider),

            // Manuelle Belohnungen anzeigen (falls vorhanden)
            if (_manualRewards.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _manualRewards.map((reward) {
                    return Text(
                      '• Erhalte ${reward['points']} Punkt(e) jedes Mal.',
                      style: TextStyle(color: Colors.lightBlue[200], fontSize: schriftProvider.allgemeineSchriftgroesse * 0.85),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: Colors.grey[700]),

            // Verknüpfte Bestrafung
            _infoRow(Icons.handshake, 'Bestrafung:', punishmentTitle, schriftProvider),

            // Manuelle Bestrafungen anzeigen (falls vorhanden)
            if (_manualPunishments.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _manualPunishments.map((punishment) {
                    return Text(
                      '• Zieht bei Nichterfüllung ${punishment['points']} Punkte ab.',
                      style: TextStyle(color: Colors.red[300], fontSize: schriftProvider.allgemeineSchriftgroesse * 0.85),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _infoRow(IconData icon, String label, String value, SchriftgroesseProvider schriftProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: schriftProvider.allgemeineSchriftgroesse * 1.2),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    String value,
    IconData icon,
    SchriftgroesseProvider schriftProvider, {
    bool iconOnly = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: schriftProvider.allgemeineSchriftgroesse * 1.2, color: Colors.white70),
          const SizedBox(width: 6),
          if (!iconOnly)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.75, color: Colors.grey[400])),
                  Text(value, style: TextStyle(fontSize: schriftProvider.allgemeineSchriftgroesse * 0.9, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final schriftProvider = Provider.of<SchriftgroesseProvider>(context);

    final stepIcons = [
      Icons.home,
      Icons.favorite_border,
      Icons.add_circle_outline,
      Icons.person_outline,
    ];

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Container(
        width: 500,
        height: 650,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey[900],
        ),
        child: Column(
          children: [
            // Obere Leiste mit Glow-Icons und X zum Schließen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(stepIcons.length, (index) {
                        final isActive = _currentStep == index;
                        return GestureDetector(
                          onTap: () {
                            if (_formKeys[_currentStep].currentState?.validate() ?? true) {
                              _formKeys[_currentStep].currentState?.save();
                              setState(() {
                                _currentStep = index;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bitte alle Pflichtfelder ausfüllen.')),
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.blueAccent.withOpacity(0.7),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              stepIcons[index],
                              size: 32,
                              color: isActive ? Colors.blueAccent : Colors.grey[400],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.blueAccent, height: 1),
            Expanded(
              child: _buildStepContent(_currentStep),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _previousStep();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: favoriteColor,
                          side: BorderSide(color: favoriteColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Zurück', style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
Expanded(
  child: ElevatedButton(
    onPressed: _isSubmitting ? null : _nextStep,
    style: ElevatedButton.styleFrom(
      backgroundColor: favoriteColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: _isSubmitting
      ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
      : Text(
          _currentStep == 3 ? 'Aufgabe erstellen' : 'Weiter',
          style: TextStyle(fontSize: schriftProvider.buttonSchriftgroesse),
        ),
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
}
