import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BugListScreen extends StatelessWidget {
  const BugListScreen({Key? key}) : super(key: key);

  String _statusColor(String status) {
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
                  leading: Text(
                    data['severity'] != null ? "⚡️${data['severity']}" : "⚡️?",
                    style: const TextStyle(fontSize: 20),
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
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (data['status'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${_statusColor(data['status'])} Status: ${data['status']}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (data['screenshotUrl'] != null && data['screenshotUrl'] != '')
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              // Bild in neuem Screen/Browser öffnen
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
