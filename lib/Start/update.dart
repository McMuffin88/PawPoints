import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class InitService {
  static bool _alreadyInitialized = false;

  static Future<void> runOncePerAppStart([BuildContext? context]) async {
    if (_alreadyInitialized) return;
    _alreadyInitialized = true;

    await checkAppVersion(context);
    await updatePushTokens();
    await loadProfileRequirements();
  }

  static Future<void> checkAppVersion(BuildContext? context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('checkAppVersion');
      final result = await callable.call({'currentVersion': currentVersion});
      final data = result.data;

      final outdated = data['outdated'] == true;
      final updateUrl = data['updateUrl'];

      if (outdated && context != null && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUpdateDialog(updateUrl, context);
        });
      } else {
        print('✅ App-Version $currentVersion ist aktuell.');
      }
    } catch (e) {
      print('⚠️ Fehler beim Versionscheck: $e');
    }
  }

  static void _showUpdateDialog(String url, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update verfügbar'),
        content: const Text(
            'Eine neue Version der App ist verfügbar. Bitte aktualisiere, um alle Funktionen nutzen zu können.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Später'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (url.isNotEmpty) {
                await _downloadAndInstallApk(url, context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Keine Update-URL verfügbar.')),
                );
              }
            },
            child: const Text('Jetzt aktualisieren'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstallApk(String apkUrl, BuildContext context) async {
    if (!context.mounted) return;

    try {
      var manageStorageStatus = await Permission.manageExternalStorage.request();
      if (!manageStorageStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bitte aktiviere 'Alle Dateien verwalten' in den App-Einstellungen."),
            backgroundColor: Colors.red,
          ),
        );
        await openAppSettings();
        return;
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download-Verzeichnis konnte nicht gefunden werden.")),
        );
        return;
      }

      final savePath = '${directory.path}/pawpoints_update.apk';
      final dio = Dio();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update wird geladen..."), backgroundColor: Colors.green),
      );

      await dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('📦 Download-Fortschritt: $progress%');
          }
        },
        options: Options(followRedirects: true, receiveTimeout: const Duration(minutes: 5)),
        deleteOnError: true,
      );

      final file = File(savePath);
      if (!await file.exists() || await file.length() < 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download fehlgeschlagen oder Datei beschädigt.")),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download abgeschlossen, Installation startet...")),
      );

      await OpenFile.open(savePath);
    } catch (e) {
      print('❌ Fehler beim Update-Download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Laden der neuen Version: $e"), backgroundColor: Colors.red),
      );
    }
  }

  static Future<void> updatePushTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(token)
            .set({'createdAt': FieldValue.serverTimestamp()});
        print('🔑 Token gespeichert: $token');
      }
    } catch (e) {
      print('⚠️ Fehler beim Speichern des Tokens: $e');
    }
  }

  static Future<void> loadProfileRequirements() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getProfileRequirements');
      final result = await callable.call();
      final data = result.data;

      print('📋 Profil-Pflichtfelder: ${data['requiredFields']}');
    } catch (e) {
      print('⚠️ Fehler beim Laden der Profilanforderungen: $e');
    }
  }
}
