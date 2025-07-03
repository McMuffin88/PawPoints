import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:io' show Platform, File;
import 'package:image_picker/image_picker.dart';

class FeedbackOrSupportScreen extends StatefulWidget {
  const FeedbackOrSupportScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackOrSupportScreen> createState() => _FeedbackOrSupportScreenState();
}

class _FeedbackOrSupportScreenState extends State<FeedbackOrSupportScreen> {
  String? selectedMode;
  int severity = 3;
  String? category;
  final TextEditingController messageController = TextEditingController();
  XFile? screenshot;
  bool isSending = false;

  String appVersion = '';
  String os = '';
  String deviceInfo = '';

  final List<String> categories = [
    'Profil',
    'Shop',
    'Aufgaben',
    'Berechtigungen',
    'Verbindung',
    'Premium',
    'Anderes',
  ];

  final List<String> plannedFeatures = [
    'Gruppenverwaltung',
    'Statistik',
    'Communityfunktionen',
    'Matching',
    'Kalenderintegration',
  ];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String platform = '';
    String model = '';

    if (kIsWeb) {
      platform = "Web";
      final userAgent = html.window.navigator.userAgent;
      String browser = "Unbekannter Browser";
      String osVersion = "Unbekanntes System";

      if (userAgent.contains('Edg/')) {
        browser = 'Microsoft Edge';
      } else if (userAgent.contains('OPR/') || userAgent.contains('Opera')) {
        browser = 'Opera';
      } else if (userAgent.contains('Chrome') && !userAgent.contains('Edg/')) {
        browser = 'Chrome';
      } else if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
        browser = 'Safari';
      } else if (userAgent.contains('Firefox')) {
        browser = 'Firefox';
      } else if (userAgent.contains('MSIE') || userAgent.contains('Trident/')) {
        browser = 'Internet Explorer';
      }

      if (userAgent.contains('Windows NT 10')) {
        osVersion = 'Windows 10';
      } else if (userAgent.contains('Windows NT 11')) {
        osVersion = 'Windows 11';
      } else if (userAgent.contains('Windows NT 6.1')) {
        osVersion = 'Windows 7';
      } else if (userAgent.contains('Macintosh')) {
        osVersion = 'macOS';
      } else if (userAgent.contains('Linux')) {
        osVersion = 'Linux';
      } else if (userAgent.contains('Android')) {
        osVersion = 'Android';
      } else if (userAgent.contains('iPhone') || userAgent.contains('iPad')) {
        osVersion = 'iOS';
      }

      model = "$browser, $osVersion";
    } else if (Platform.isAndroid) {
      platform = "Android";
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;
      model = androidInfo.model ?? '';
    } else if (Platform.isIOS) {
      platform = "iOS";
      final deviceInfoPlugin = DeviceInfoPlugin();
      final iosInfo = await deviceInfoPlugin.iosInfo;
      model = iosInfo.utsname.machine ?? '';
    } else if (Platform.isMacOS) {
      platform = "macOS";
      model = '';
    } else if (Platform.isWindows) {
      platform = "Windows";
      model = '';
    } else if (Platform.isLinux) {
      platform = "Linux";
      model = '';
    } else {
      platform = "Unbekannt";
      model = '';
    }

    setState(() {
      appVersion = version;
      os = platform;
      deviceInfo = model;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        screenshot = picked;
      });
    }
  }

  Future<String?> _uploadScreenshot(XFile file) async {
    final fileName = "feedback_${DateTime.now().millisecondsSinceEpoch}_${file.name}";
    final ref = FirebaseStorage.instance.ref('feedback_screenshots').child(fileName);

    UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(bytes);
    } else {
      uploadTask = ref.putFile(File(file.path));
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<bool> _isDuplicateFeedback(String category, String description) async {
    final query = await FirebaseFirestore.instance
        .collection('feedback')
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    for (var doc in query.docs) {
      final String previousMsg = (doc['message'] as String).toLowerCase();
      final String currentMsg = description.toLowerCase();
      if (previousMsg.length > 10 &&
          currentMsg.length > 10 &&
          previousMsg.substring(0, 15) == currentMsg.substring(0, 15)) {
        return true;
      }
    }
    return false;
  }

  bool _isPlannedFeature(String description) {
    return plannedFeatures.any((feature) =>
        description.toLowerCase().contains(feature.toLowerCase()));
  }

  Future<int> _getNextBugNumber() async {
    print("Frage höchste Bugnummer ab...");
    final query = await FirebaseFirestore.instance
        .collection('feedback')
        .orderBy('bugNumber', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      print("Noch keine Bugs vorhanden, setze bugNumber auf 1.");
      return 1;
    }
    final maxNum = query.docs.first['bugNumber'] ?? 0;
    print("Höchste gefundene bugNumber: $maxNum");
    return (maxNum as int) + 1;
  }

  Future<void> _sendFeedback() async {
    print("Starte Bug-Absenden...");
    if (category == null || messageController.text.trim().isEmpty) {
      print("Kategorie oder Nachricht fehlt!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Rubrik wählen und eine Nachricht eingeben.')),
      );
      return;
    }

    final msg = messageController.text.trim();

    if (await _isDuplicateFeedback(category!, msg)) {
      print("Feedback bereits vorhanden!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dieser Fehler wurde bereits gemeldet. Vielen Dank!')),
      );
      return;
    }

    if (_isPlannedFeature(msg)) {
      print("Feature ist bereits geplant!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Diese Funktion ist in dieser Alpha-Version noch nicht verfügbar.\nSchau in die Roadmap!',
        )),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    String? screenshotUrl;
    if (screenshot != null) {
      screenshotUrl = await _uploadScreenshot(screenshot!);
    }

    int bugNumber = 0;
    try {
      bugNumber = await _getNextBugNumber();
      print("Vergabene bugNumber: $bugNumber");
    } catch (e) {
      print("FEHLER beim Bugnummer-Lesen: $e");
      bugNumber = 1;
    }

    print("Sende Bug an Firestore...");
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'bugNumber': bugNumber,
        'severity': severity,
        'category': category,
        'message': msg,
        'appVersion': appVersion,
        'os': os,
        'deviceInfo': deviceInfo,
        'screenshotUrl': screenshotUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'offen',
      });
      print("Firestore-Schreiben erfolgreich!");
    } catch (e, stack) {
      print("FEHLER beim Schreiben in Firestore: $e");
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Schreiben in Firestore: $e")),
      );
      setState(() {
        isSending = false;
      });
      return;
    }

    setState(() {
      isSending = false;
      screenshot = null;
      messageController.clear();
      category = null;
      severity = 3;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Erfolg'),
        content: const Text('Dein Feedback wurde gemeldet.\nDu siehst jetzt die gemeldeten Bugs.'),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const BugListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Support & Feedback")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: selectedMode == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Möchtest du Feedback geben oder den Support kontaktieren?",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.list_alt),
                            label: const Text("Gemeldete Bugs ansehen"),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const BugListScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.bug_report),
                            label: const Text("Feedback / Bug melden"),
                            onPressed: () {
                              setState(() {
                                selectedMode = 'feedback';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.support_agent),
                            label: const Text("Support (Chat)"),
                            onPressed: () {
                              setState(() {
                                selectedMode = 'support';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : selectedMode == 'support'
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.support_agent, size: 60, color: Colors.grey),
                        const SizedBox(height: 24),
                        const Text(
                          "Der Support-Chat ist in Kürze verfügbar.\nBitte verwende solange das Feedback-Formular.",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          child: const Text("Zurück"),
                          onPressed: () {
                            setState(() {
                              selectedMode = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildFeedbackForm(context),
      ),
    );
  }

  Widget _buildFeedbackForm(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Zurück"),
                  onPressed: () {
                    setState(() {
                      selectedMode = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Wie kritisch ist das Problem?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        severity = value;
                      });
                    },
                    icon: Icon(
                      Icons.warning,
                      color: severity >= value ? Colors.red : Colors.grey,
                    ),
                    tooltip: "$value von 5",
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Rubrik (wo ist das Problem aufgetreten)?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Rubrik auswählen",
                ),
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    category = val;
                  });
                },
                value: category,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Beschreibung des Problems:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Was ist passiert? Wie kann man den Fehler nachstellen?",
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text("Screenshot anhängen"),
                  ),
                  const SizedBox(width: 8),
                  if (screenshot != null)
                    const Text(
                      "Screenshot ausgewählt",
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                appVersion.isNotEmpty && os.isNotEmpty
                    ? "Version: $appVersion | $os${deviceInfo.isNotEmpty ? " $deviceInfo" : ""}"
                    : "Geräteinfo wird geladen...",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text("Gemeldete Bugs ansehen"),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const BugListScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton.icon(
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text("Feedback absenden"),
                  onPressed: isSending ? null : _sendFeedback,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// Bug-Viewer für Feedback/Bugs
// ---------------------------
class BugListScreen extends StatelessWidget {
  const BugListScreen({Key? key}) : super(key: key);

  String _statusSymbol(String status) {
    switch (status) {
      case "erledigt":
        return "✅";
      case "in Bearbeitung":
        return "🕐";
      case "offen":
      default:
        return "🟠";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gemeldete Bugs & Feedback")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Keine Bugs gefunden."));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data['bugNumber'] != null
                            ? "#${data['bugNumber']}"
                            : "?",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['severity'] != null
                            ? "⚡️${data['severity']}"
                            : "⚡️?",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  title: Text(
                    data['category'] ?? "Unbekannt",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['message'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(data['message']),
                        ),
                      Row(
                        children: [
                          Text(
                            "${data['appVersion'] ?? ''} | ${data['os'] ?? ''} ${data['deviceInfo'] ?? ''}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (data['status'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${_statusSymbol(data['status'])} Status: ${data['status']}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (data['screenshotUrl'] != null &&
                          data['screenshotUrl'] != '')
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(data['screenshotUrl']),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Screenshot anzeigen",
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
