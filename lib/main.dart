// main.dart

import 'dart:io';
import 'dart:convert'; // Für utf8.encode
import 'package:crypto/crypto.dart'; // Für SHA256 Hashing
import 'dart:async'; // Für StreamController

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart'; // This import contains DefaultFirebaseOptions

// Wichtig: Diese Dateien müssen in Ihrem Projekt existieren!
import 'Start/bottom_navigator.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http; // Nicht mehr benötigt, da HttpHeaders.authorizationHeader entfernt wird


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const PawPointsApp());
}



// SHA256 Hashing Funktion
String sha256hash(String input) {
  var bytes = utf8.encode(input); // Daten, die gehasht werden
  var digest = sha256.convert(bytes); // Verwende die sha256-Instanz aus dem crypto-Paket
  return digest.toString();
}

// Globaler StreamController für Theme-Farben
final _themeColorStreamController = StreamController<Color>.broadcast();

class PawPointsApp extends StatefulWidget {
  const PawPointsApp({super.key});

  // Methode, um auf den State zuzugreifen und die Farbe zu ändern
  static _PawPointsAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_PawPointsAppState>()!;

  @override
  State<PawPointsApp> createState() => _PawPointsAppState();
}

class _PawPointsAppState extends State<PawPointsApp> {
  Color _currentThemeColor = Colors.orange; // Standardfarbe

  @override
  void initState() {
    super.initState();
    // Höre auf Änderungen im Stream
    _themeColorStreamController.stream.listen((color) {
      if (mounted) {
        setState(() {
          _currentThemeColor = color;
        });
      }
    });
  }

  @override
  void dispose() {
    _themeColorStreamController.close();
    super.dispose();
  }

  // Methode, um die Farbe von außen zu setzen
  void setThemeColor(Color newColor) {
    _themeColorStreamController.add(newColor);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PawPoints',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: _currentThemeColor, // Dynamische Primärfarbe
          secondary: (_currentThemeColor is MaterialColor)
              ? (_currentThemeColor as MaterialColor).shade700
              : Colors.grey, // Robuster Fallback
          onPrimary: Colors.black,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white70,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          hintStyle: const TextStyle(color: Colors.white54),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentThemeColor, // Dynamische Button-Farbe
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _currentThemeColor, // Dynamische TextButton-Farbe
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool showLogin = true;
  bool loading = false;
  User? _user;
  bool _showProfileForm = false;
  Map<String, dynamic>? _profileData;
  List<String> _missingFields = [];
  bool _showPinVerification = false;
  bool _pinVerified = false; // Zustand: true, wenn PIN einmal korrekt eingegeben wurde
  String _appVersion = 'Lade Version...'; // Zustand für die App-Version

  // KORREKTUR: Diese Liste MUSS exakt den Firestore-Feldnamen entsprechen (Kleinschreibung).
  final List<String> requiredProfileFields = [
    'benutzername',
    'vorname',
    'nachname',
    'geburtsdatum',
    'gender',
    'roles',
  ];

  // Mapping von Farbnamen zu Color-Objekten
  final Map<String, Color> _colorOptions = {
    'Orange': Colors.orange,
    'Rot': Colors.red,
    'Blau': Colors.blue,
    'Grün': Colors.green,
    'Lila': Colors.purple,
    'Pink': Colors.pink,
    'Türkis': Colors.teal,
    // Fügen Sie hier bei Bedarf weitere Farben hinzu
  };


  @override
  void initState() {
    super.initState();
    _loadAppVersion(); // App-Version laden
    WidgetsBinding.instance.addObserver(this); // Observer registrieren
    _checkAppVersion();
    // Start listening to auth state changes to react to login/logout
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is logged in, proceed with _afterLogin checks
        await _afterLogin(user);
      } else {
        // User is logged out, reset state to show login screen and default color
        setState(() {
          _user = null;
          _profileData = null;
          _showProfileForm = false;
          _showPinVerification = false;
          _pinVerified = false; // Reset PIN verification state on logout
          showLogin = true;
          loading = false;
          PawPointsApp.of(context).setThemeColor(Colors.orange); // Standardfarbe wiederherstellen
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Observer deregistrieren
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App Lifecycle State: $state'); // Debug-Ausgabe hinzufügen

    // Prüfe die Bedingungen nur, wenn ein Benutzer angemeldet ist und Profil geladen wurde
    if (_user != null && _profileData != null && _profileData!['diskretModus'] == true) {
      if (state == AppLifecycleState.resumed) {
        // App kommt in den Vordergrund
        // Wenn PIN noch NICHT verifiziert wurde (oder nach einem Hintergrund-Event zurückgesetzt wurde)
        if (!_pinVerified) {
          setState(() {
            _showPinVerification = true;
            showLogin = false; // Stellt sicher, dass Login/Registrierungsformulare ausgeblendet sind
            _showProfileForm = false; // Stellt sicher, dass das Profilformular ausgeblendet ist
            print('DEBUG: App Resumed, showing PIN verification.');
          });
        } else {
          print('DEBUG: App Resumed, PIN already verified for this session.');
        }
      } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        // App geht in den Hintergrund. Hier setzen wir _pinVerified IMMER zurück,
        // damit beim nächsten resume die Abfrage kommt.
        if (_pinVerified) { // Setze nur zurück, wenn es vorher verifiziert war
          setState(() {
            _pinVerified = false; // Wichtig: PIN-Status zurücksetzen!
            print('DEBUG: App going to background, resetting PIN verification state.');
          });
        }
      }
    } else {
      print('DEBUG: PIN check skipped. User: $_user, Profile: $_profileData, Diskretmodus: ${_profileData?['diskretModus']}, PinVerified: $_pinVerified');
    }
  }

  // Methode zum Laden der App-Version
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'Version ${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Version unbekannt';
      });
      print('Fehler beim Laden der App-Version: $e');
    }
  }

  Future<void> _checkAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final result = await FirebaseFunctions.instance
          .httpsCallable('checkAppVersion')
          .call({'currentVersion': currentVersion});

      final data = result.data as Map<String, dynamic>;
      final bool outdated = data['outdated'] ?? false;
      final String? updateUrl = data['updateUrl'];

      if (outdated && updateUrl != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUpdateDialog(updateUrl);
        });
      }
    } catch (e) {
      print('Versionscheck Fehler: $e');
    }
  }

Future<bool> checkStoragePermission() async {
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    // Für SDK < 30 fallback
    final status = await Permission.storage.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }
  return true; // iOS, Web ...
}

// Dies ist die aktualisierte Funktion, die den PAT entfernt
Future<void> _downloadAndInstallApk(String apkUrl, BuildContext context) async {
  // Stellen Sie sicher, dass der Kontext gültig ist
  if (!context.mounted) {
    if (kDebugMode) {
      print('DEBUG: Kontext ist nicht gemountet. Abbruch des Downloads.');
    }
    return;
  }

  try {
    // 1. Zuerst die Berechtigung 'MANAGE_EXTERNAL_STORAGE' (Alle Dateien verwalten) prüfen und anfordern.
    // Dies ist entscheidend für den Zugriff auf den öffentlichen Download-Ordner,
    // besonders wenn Sie die Berechtigung manuell erteilt haben.
    var manageStorageStatus = await Permission.manageExternalStorage.request();

    if (kDebugMode) {
      print("DEBUG: Status MANAGE_EXTERNAL_STORAGE: ${manageStorageStatus.isGranted}");
      print("DEBUG: Details MANAGE_EXTERNAL_STORAGE Status: $manageStorageStatus");
    }

    if (!manageStorageStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitte aktivieren Sie 'Alle Dateien verwalten' in den App-Einstellungen."),
          backgroundColor: Colors.red,
        ),
      );
      // Leite den Nutzer zu den App-Einstellungen, damit er die Berechtigung manuell erteilen kann.
      await openAppSettings();
      return; // Download-Vorgang abbrechen, da die Berechtigung fehlt.
    }

    // Wenn MANAGE_EXTERNAL_STORAGE erteilt ist, sollte der direkte Speicherzugriff funktionieren.
    // Wir prüfen die allgemeine Speicherberechtigung (READ/WRITE_EXTERNAL_STORAGE) nur zur Sicherheit.
    var storagePermissionStatus = await Permission.storage.request();
    if (kDebugMode) {
      print("DEBUG: Status allgemeine Speicherberechtigung: ${storagePermissionStatus.isGranted}");
      print("DEBUG: Details allgemeine Speicherberechtigung Status: $storagePermissionStatus");
    }
    // Obwohl MANAGE_EXTERNAL_STORAGE erteilt ist, kann Permission.storage immer noch denied sein,
    // wenn die App keine Medienberechtigungen hat. Für APK-Downloads ist MANAGE_EXTERNAL_STORAGE relevanter.

    // 2. Den korrekten, anwendungsspezifischen Download-Verzeichnis-Pfad finden.
    // getDownloadsDirectory() ist für öffentliche Downloads gedacht.
    // Bei MANAGE_EXTERNAL_STORAGE ist es aber sicherer, ein app-spezifisches Verzeichnis zu verwenden,
    // das auch ohne MANAGE_EXTERNAL_STORAGE zugänglich wäre, aber wir nutzen den Download-Ordner,
    // wie in den vorherigen Logs zu sehen war.
    final directory = await getDownloadsDirectory(); 
    // Alternativ: final directory = await getApplicationDocumentsDirectory(); für einen privaten App-Ordner

    if (directory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download-Verzeichnis konnte nicht gefunden werden."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Den vollständigen Pfad zur Datei erstellen.
    final savePath = '${directory.path}/pawpoints_update.apk';
    
    // VERWENDEN SIE HIER IHREN NEUEN GITHUB-LINK (Repository ist jetzt öffentlich)
    const String githubDirectDownloadUrl = 'https://github.com/McMuffin88/PawPoints/releases/download/Updater/app-release.apk';

    if (kDebugMode) {
      print("DEBUG: Die APK-Datei wird heruntergeladen von: $githubDirectDownloadUrl");
      print("DEBUG: Die APK-Datei wird hier gespeichert: $savePath");
    }

    final dio = Dio();

    // Dio Interceptors für Debugging wurden entfernt, da nicht mehr benötigt.
    // if (kDebugMode) {
    //   dio.interceptors.add(InterceptorsWrapper(
    //     onRequest: (options, handler) {
    //       print('Dio Request URL: ${options.uri}');
    //       print('Dio Request Headers: ${options.headers}');
    //       if (options.headers.containsKey(HttpHeaders.authorizationHeader)) {
    //         print('Authorization Header found in request!');
    //       } else {
    //         print('Authorization Header NOT found in request!');
    //       }
    //       return handler.next(options);
    //     },
    //     onResponse: (response, handler) {
    //       print('Dio Response Status Code: ${response.statusCode}');
    //       print('Dio Response Headers: ${response.headers}');
    //       print('Dio Response Data (First 200 chars): ${response.data.toString().substring(0, response.data.toString().length > 200 ? 200 : response.data.toString().length)}');
    //       return handler.next(response);
    //     },
    //     onError: (DioException e, handler) {
    //       print('Dio Error Response: ${e.response?.statusCode}');
    //       print('Dio Error Message: ${e.message}');
    //       print('Dio Error Response Data: ${e.response?.data}');
    //       return handler.next(e);
    //     },
    //   ));
    // }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Update wird geladen..."), backgroundColor: Colors.green),
    );

    // 4. Download starten (ohne Authentifizierungs-Header)
    await dio.download(
      githubDirectDownloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          double progress = received / total;
          if (kDebugMode) {
            print('Download-Fortschritt: ${(progress * 100).toStringAsFixed(0)}% (${received} von ${total} Bytes)');
          }
        } else {
          if (kDebugMode) {
            print('Download-Fortschritt: ${received} Bytes heruntergeladen, Gesamtgröße unbekannt.');
          }
        }
      },
      options: Options(
        // headers: { HttpHeaders.authorizationHeader: 'token $githubToken', }, // Diese Zeilen sind jetzt entfernt
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
      deleteOnError: true,
    );

    print("Download erfolgreich!");

    // 5. Heruntergeladene Datei prüfen.
    final downloadedFile = File(savePath);
    if (await downloadedFile.exists()) {
      final fileSize = await downloadedFile.length();
      if (kDebugMode) {
        print('DEBUG: Heruntergeladene Datei hat eine Größe von $fileSize Bytes.');
      }
      if (fileSize < 1024 * 1024) { // Warnung, wenn die Datei kleiner als 1 MB ist (potenziell beschädigt/unvollständig)
        print('WARNUNG: Die heruntergeladene Datei ist unerwartet klein. Möglicherweise ist der Download fehlgeschlagen.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download fehlgeschlagen oder Datei beschädigt. Bitte versuchen Sie es erneut."), backgroundColor: Colors.orange),
        );
        return; // Abbruch
      }
    } else {
      print('FEHLER: Heruntergeladene Datei wurde am erwarteten Pfad nicht gefunden!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download fehlgeschlagen – Datei nicht gefunden."), backgroundColor: Colors.red),
      );
      return; // Abbruch
    }

    // 6. Datei zur Installation öffnen.
    print("APK im Download-Ordner gefunden. Öffne Datei zum Installieren...");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Download abgeschlossen, Installation startet...")),
    );
    
    // openFile wird den Android-Installer aufrufen, der dann die Berechtigung REQUEST_INSTALL_PACKAGES
    // über das System-UI abfragt, falls sie nicht bereits erteilt wurde.
    await OpenFile.open(savePath);

  } on DioException catch (e) {
    if (kDebugMode) {
      print("FEHLER (Dio): ${e.message}");
      if (e.response != null) {
        print("Dio-Fehler Response: ${e.response?.statusCode} - ${e.response?.statusMessage}");
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fehler beim Download: ${e.message}"), backgroundColor: Colors.red),
    );
  } catch (e) {
    if (kDebugMode) {
      print("ALLGEMEINER FEHLER beim Update-Download: $e");
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fehler beim Laden der neuen Version: $e"), backgroundColor: Colors.red),
    );
  }
}


Future<bool> requestFullStoragePermission(BuildContext context) async {
  if (Platform.isAndroid) {
    // Android 13+: diese Rechte abfragen, darunter reicht storage/manageExternalStorage
    final List<Permission> permissions = [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];

    bool allGranted = true;
    bool anyPermanentlyDenied = false;

    for (final permission in permissions) {
      final status = await permission.request();
      print('Permission ${permission.toString()}: $status');
      if (!status.isGranted) {
        allGranted = false;
        if (status.isPermanentlyDenied) {
          anyPermanentlyDenied = true;
        }
      }
    }

    if (!allGranted) {
      if (anyPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Bitte erlaube den Speicherzugriff in den App-Einstellungen!'),
            action: SnackBarAction(
              label: 'Einstellungen',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ohne Speicherfreigabe kann kein Download durchgeführt werden!')),
        );
      }
      return false;
    }
    return true;
  }
  // iOS/andere Plattformen: Immer true zurück
  return true;
}
  void _showUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update verfügbar'),
        content: const Text(
          'Eine neue Version der App ist verfügbar. Bitte aktualisiere, um alle Funktionen nutzen zu können.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Später'),
          ),
ElevatedButton(
  onPressed: () async {
    Navigator.of(ctx).pop(); // Dialog schließen
    if (url.isNotEmpty) {
      await _downloadAndInstallApk(url, context);
    } else {
      print('Update-URL ist leer oder null.');
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

  void toggle() => setState(() => showLogin = !showLogin);

  Future<void> _afterLogin(User user) async {
    if (!mounted) return;
    setState(() => loading = true);
    await user.reload(); // Ensure current user data is fresh
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutzer konnte nicht gefunden werden!')),
      );
      return;
    }

    if (!currentUser.emailVerified) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bitte bestätige zuerst deine E-Mail-Adresse! Wir haben dir eine neue Bestätigung gesendet.'),
          duration: Duration(seconds: 5),
        ),
      );
      try {
        await currentUser.sendEmailVerification();
      } catch (_) {}
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final userDoc = await userDocRef.get();

    // WICHTIG: Erstelle das Dokument, falls es noch nicht existiert!
    if (!userDoc.exists) {
      print('DEBUG: User document does not exist, creating default profile.');
      await userDocRef.set({
        'uid': currentUser.uid,
        'email': currentUser.email,
        'createdAt': FieldValue.serverTimestamp(),
        // Initialisiere wichtige Felder mit Standardwerten
        'benutzername': null,
        'vorname': null,
        'nachname': null,
        'geburtsdatum': null,
        'gender': null,
        'roles': [],
        'diskretModus': false, // Wichtig: Default auf false
        'pinHash': '', // Wichtig: Default leer
        'ageHidden': false,
        'profileImageUrl': '',
        'plz': null,
        'city': null,
        'doggyIds': [],
        'herrchenIds': [],
        'premium': {'doggy': false, 'herrchen': false},
        'favoriteColor': 'Orange', // Standard-Lieblingsfarbe setzen
      });
      // Nach dem Erstellen das Dokument erneut laden, damit _profileData aktuell ist
      final newUserDoc = await userDocRef.get();
      if (!mounted) return;
      setState(() {
        loading = false;
        _user = currentUser;
        _profileData = newUserDoc.data(); // Jetzt mit den neu erstellten Daten
      });
      // Da es ein neues Profil ist, gehen wir direkt zum Profilformular
      _missingFields = List.from(requiredProfileFields);
      setState(() => _showProfileForm = true);
      return; // Beende hier und zeige das Profilformular an
    } else {
      // Bestehendes Profil laden
      if (!mounted) return;
      setState(() {
        loading = false;
        _user = currentUser;
        _profileData = userDoc.data();
      });

      // Lieblingsfarbe anwenden, falls vorhanden
      if (_profileData != null && _profileData!['favoriteColor'] != null) {
        final String? favColorName = _profileData!['favoriteColor'] as String?;
        if (favColorName != null && _colorOptions.containsKey(favColorName)) {
          PawPointsApp.of(context).setThemeColor(_colorOptions[favColorName]!);
        } else {
          PawPointsApp.of(context).setThemeColor(Colors.orange); // Fallback auf Standardfarbe
        }
      }
    }

    // PIN-Abfrage als erste Priorität, NACHDEM das Profil geladen/erstellt wurde
    if (_profileData != null && _profileData!['diskretModus'] == true && _profileData!['pinHash'] != null && _profileData!['pinHash'].isNotEmpty && !_pinVerified) {
      if (!mounted) return;
      setState(() {
        _showPinVerification = true;
        showLogin = false; // Stellt sicher, dass Login/Registrierungsformulare ausgeblendet sind
        _showProfileForm = false; // Stellt sicher, dass das Profilformular ausgeblendet ist
      });
      return; // Stoppe weitere Verarbeitung, zeige PIN-Bildschirm
    }

    // Wenn Profil unvollständig ist (oder nach oben neu erstellt wurde)
    _missingFields = [];
    if (_profileData != null) {
      for (var field in requiredProfileFields) {
        if (!_profileData!.containsKey(field) ||
            _profileData![field] == null ||
            (_profileData![field] is String && _profileData![field].toString().isEmpty) ||
            (field == 'roles' && (_profileData![field] as List).isEmpty)) { // Spezifische Prüfung für leere Rollen
          _missingFields.add(field);
        }
      }
    }

    if (_missingFields.isNotEmpty) {
      if (!mounted) return;
      setState(() => _showProfileForm = true);
      return;
    }

    // Wenn alles okay ist (keine PIN, kein unvollständiges Profil), leite zur Rolle weiter
    final roles = List<String>.from(_profileData?['roles'] ?? []);
    if (roles.contains('doggy')) {
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => BottomNavigator(role: "doggy")));
    } else if (roles.contains('herrchen')) {
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => BottomNavigator(role: "herrchen")));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle im Profil mindestens eine Rolle aus!')),
      );
      setState(() => _showProfileForm = true); // Go back to profile to select role
    }
  }

  void _onProfileSaved() {
    if (!mounted) return;
    setState(() {
      _showProfileForm = false;
      _missingFields = [];
    });
    // After profile is saved, re-evaluate the next step (e.g., check PIN or navigate to role screen)
    if (_user != null) {
      _afterLogin(_user!); // Re-run the logic to determine where to go next
    }
  }


  void _onPinVerified(bool verified) async {
    if (!mounted) return;
    setState(() {
      _showPinVerification = false;
      _pinVerified = verified; // Setze den Verifizierungsstatus
    });

    if (verified) {
      // If PIN is correct, navigate based on roles
      final roles = List<String>.from(_profileData?['roles'] ?? []);
      if (roles.contains('doggy')) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => BottomNavigator(role: "doggy")));;
      } else if (roles.contains('herrchen')) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => BottomNavigator(role: "herrchen")));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte wähle im Profil mindestens eine Rolle aus!')),
        );
        setState(() => _showProfileForm = true);
      }
    } else {
      // If PIN is incorrect, log out the user
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _user = null;
        _showProfileForm = false;
        showLogin = true; // Go back to login
        _pinVerified = false; // Reset for security
        PawPointsApp.of(context).setThemeColor(Colors.orange); // Standardfarbe wiederherstellen
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falsche PIN. Bitte erneut anmelden.')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_showPinVerification) {
      // When on PIN verification screen, pressing back logs out
      await FirebaseAuth.instance.signOut();
      if (!mounted) return false;
      setState(() {
        _user = null;
        _showProfileForm = false;
        showLogin = true;
        _showPinVerification = false;
        _pinVerified = false; // Reset for security
        PawPointsApp.of(context).setThemeColor(Colors.orange); // Standardfarbe wiederherstellen
      });
      return false; // Prevent closing the app
    }
    // Default back button behavior (e.g., app exit confirmation on Android)
    if (!Platform.isAndroid) return true; // Allow closing on other platforms
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('App beenden'),
            content: const Text('Möchtest du die App wirklich beenden?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Beenden')),
            ],
          ),
        ) ??
        false;
    return shouldExit;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: const Color(0xFF1E1E1E),
              body: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // 1. Check for PIN Verification first
                      if (_showPinVerification && _user != null && _profileData != null)
                        PinVerificationScreen(
                          storedPinHash: _profileData!['pinHash'],
                          onVerified: _onPinVerified,
                        )
                      // 2. Then check for Profile Form
                      else if (_showProfileForm && _user != null)
                        ProfileForm(
                          user: _user!,
                          onSaved: _onProfileSaved, // Calls _onProfileSaved, which re-evaluates
                          missingFields: _missingFields,
                          requiredFields: requiredProfileFields,
                          colorOptions: _colorOptions, // Übergabe der Farboptionen
                        )
                      // 3. Finally, show Login/Register forms
                      else if (showLogin)
                        LoginForm(onSwitch: toggle, onSuccess: _afterLogin)
                      else
                        RegisterForm(onSwitch: toggle),
                      // If none of the above, it implies the user is authenticated, has a complete profile,
                      // and is not in discrete mode (or PIN was verified), so the role-based navigation
                      // within _afterLogin would have taken over.
                      
                      // NEU: Anzeige der App-Version am unteren Rand
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                        child: Text(
                          _appVersion,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Neues Widget für die PIN-Verifizierung
class PinVerificationScreen extends StatefulWidget {
  final String storedPinHash;
  final Function(bool) onVerified;

  const PinVerificationScreen({
    super.key,
    required this.storedPinHash,
    required this.onVerified,
  });

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode(); // Neuer FocusNode
  bool _loading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Automatisch das Textfeld fokussieren, sobald das Widget gerendert wird
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose(); // FocusNode dispoen
    super.dispose();
  }

  void _verifyPin() {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    final enteredPinHash = sha256hash(_pinController.text.trim());

    // DEBUG Prints (optional, kann nach erfolgreicher Fehlerbehebung entfernt werden)
    print('DEBUG: Entered PIN Hash: $enteredPinHash');
    print('DEBUG: Stored PIN Hash: ${widget.storedPinHash}');

    if (enteredPinHash == widget.storedPinHash) {
      widget.onVerified(true);
    } else {
      setState(() {
        _errorMessage = 'Falsche PIN. Bitte erneut versuchen.';
        _loading = false;
      });
      _pinController.clear();
      _pinFocusNode.requestFocus(); // Fokus nach falscher Eingabe wiederherstellen
    }
  }

  @override
  Widget build(BuildContext context) {
    // Um die Höhe des Bildschirms zu erhalten, ähnlich wie in LoginForm
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Optional: Wenn du ein Header-Bild wie im Login-Screen möchtest
          // ClipRRect(
          //   borderRadius: const BorderRadius.only(
          //     bottomRight: Radius.circular(80),
          //   ),
          //   child: Image.asset(
          //     'assets/login_header.png', // Annahme: Du hast dieses Asset
          //     width: MediaQuery.of(context).size.width,
          //     height: screenHeight * 0.35, // Anpassbare Höhe
          //     fit: BoxFit.cover,
          //   ),
          // ),
          SizedBox(height: screenHeight * 0.2), // Angepasster Abstand von oben
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              color: const Color(0xFF1C1C1C),
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PIN-Eingabe erforderlich',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      focusNode: _pinFocusNode, // FocusNode zuweisen
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        hintText: 'Bitte gib deine 6-stellige PIN ein',
                        prefixIcon: Icon(Icons.lock, color: Colors.white70),
                      ),
                      onSubmitted: (_) => _verifyPin(), // PIN verifizieren bei "Enter"
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verifyPin,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Bestätigen'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _loading ? null : () {
                        // Benutzer abmelden, wenn PIN vergessen
                        widget.onVerified(false);
                      },
                      child: const Text('PIN vergessen? Abmelden'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback onSwitch;
  final Future<void> Function(User) onSuccess;
  const LoginForm({super.key, required this.onSwitch, required this.onSuccess});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _loginInput = TextEditingController();
  final _pw = TextEditingController();
  bool _pwVisible = false;
  bool _loading = false;
  bool _rememberMe = false;

  Future<String> _getEmailFromLogin(String input) async {
    // Basic email regex check, more robust validation is done server-side by Firebase Auth
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
    if (emailRegex.hasMatch(input.trim())) {
      return input.trim(); // It's an email
    } else {
      // Assume it's a username, try to convert via Cloud Function
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('usernameToEmail') // This Cloud Function needs to exist!
            .call({'username': _loginInput.text.trim()});
        if (result.data == null || result.data['email'] == null) {
          throw Exception('Benutzername nicht gefunden oder keine E-Mail verknüpft');
        }
        return result.data['email'] as String;
      } on FirebaseFunctionsException catch (e) {
        // Handle specific Cloud Function errors if needed, but for security,
        // it's better to give a generic message to the user.
        print('Cloud Function usernameToEmail error: ${e.code} - ${e.message}');
        // Re-throw as a generic error to be caught by the outer catch block
        throw Exception('Fehler beim Abrufen der E-Mail für Benutzername.');
      } catch (e) {
        print('Unerwarteter Fehler bei usernameToEmail: $e');
        throw Exception('Fehler beim Abrufen der E-Mail für Benutzername.');
      }
    }
  }

  void _login() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final email = await _getEmailFromLogin(_loginInput.text);
      if (kIsWeb) {
        if (_rememberMe) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } else {
          await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
        }
      }
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: _pw.text.trim());
      await widget.onSuccess(cred.user!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Fehler beim Login.';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-email':
            msg = 'E-Mail/Benutzername oder Passwort falsch.'; // Generic message for security
            break;
          case 'wrong-password':
            msg = 'E-Mail/Benutzername oder Passwort falsch.'; // Generic message for security
            break;
          case 'user-disabled':
            msg = 'Dieser Nutzer wurde deaktiviert.';
            break;
          case 'too-many-requests':
            msg = 'Zu viele Anmeldeversuche. Bitte später versuchen.';
            break;
          default:
            msg = 'Anmeldefehler: ${e.message}';
            break;
        }
      } else if (e.toString().contains('Benutzername nicht gefunden') || e.toString().contains('Fehler beim Abrufen der E-Mail für Benutzername')) {
        msg = 'E-Mail/Benutzername oder Passwort falsch.'; // Generic message for security
      } else {
        msg = 'Ein unerwarteter Fehler ist aufgetreten: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // MARK: - Passwort vergessen Funktion (Serverless-Ansatz)
  void _showForgotPasswordDialog() async {
    final inputController = TextEditingController(text: _loginInput.text.trim());

    final enteredValue = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Passwort zurücksetzen'),
          content: TextField(
            controller: inputController,
            decoration: const InputDecoration(
              labelText: 'Benutzername oder E-Mail',
              hintText: 'Gib deinen registrierten Benutzernamen oder E-Mail ein',
            ),
            keyboardType: TextInputType.text, // Kann Text oder E-Mail sein
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(inputController.text.trim());
              },
              child: const Text('Senden'),
            ),
          ],
        );
      },
    );

    if (enteredValue == null || enteredValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eingabe wurde nicht gemacht.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Aufruf der Cloud Function 'sendPasswordResetByUsernameOrEmail'
      // Diese Funktion muss die Logik enthalten, um zu erkennen, ob es eine E-Mail oder ein Benutzername ist,
      // die entsprechende E-Mail-Adresse zu finden und dann die Reset-E-Mail zu senden.
      await FirebaseFunctions.instance
          .httpsCallable('sendPasswordResetByUsernameOrEmail')
          .call({'identifier': enteredValue}); // 'identifier' kann Benutzername oder E-Mail sein

      // Die Cloud Function gibt immer die gleiche Nachricht zurück, um User Enumeration zu verhindern.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Wenn ein Account mit dieser Eingabe existiert, wurde eine E-Mail zum Zurücksetzen des Passworts gesendet.')),
      );
    } on FirebaseFunctionsException catch (e) {
      // Auch hier die gleiche generische Nachricht für den Benutzer
      print('Cloud Function Error (Password Reset): ${e.code} - ${e.message}'); // Für Debugging im Log
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Beim Zurücksetzen des Passworts ist ein Fehler aufgetreten. Bitte versuche es später erneut.')),
      );
    } catch (e) {
      print('Unerwarteter Fehler (Password Reset): $e'); // Für Debugging im Log
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es später erneut.')),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(80),
            ),
            child: Image.asset(
              'assets/login_header.png',
              width: MediaQuery.of(context).size.width,
              height: screenHeight * 0.35,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              color: const Color(0xFF1C1C1C),
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Willkommen bei PawPoints',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _loginInput,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person, color: Colors.white70),
                        labelText: 'Benutzername oder E-Mail',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _pw,
                      style: const TextStyle(color: Colors.white),
                      obscureText: !_pwVisible,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                        labelText: 'Passwort',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                            icon: Icon(
                              _pwVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _pwVisible = !_pwVisible)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (kIsWeb)
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                fillColor: MaterialStateProperty.all(Theme.of(context).colorScheme.primary),
                                checkColor: Colors.black,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              ),
                              const Text(
                                'Angemeldet bleiben',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        // Changed to call the dialog function
                        TextButton(
                          onPressed: _loading ? null : _showForgotPasswordDialog,
                          child: const Text('Passwort vergessen?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Anmelden'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Noch keinen Account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(onPressed: widget.onSwitch, child: const Text("Registrieren"))
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const RegisterForm({super.key, required this.onSwitch});
  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _confirmPw = TextEditingController(); // Neues Textfeld für Passwort-Wiederholung
  bool _pwVisible = false;
  bool _confirmPwVisible = false; // Für Sichtbarkeit des zweiten Passwortfelds
  bool _loading = false;
  String? _passwordStrengthText;
  Color? _passwordStrengthColor;

  // MARK: - Passwortstärke-Einschätzung
  void _checkPasswordStrength(String password) {
    int score = 0;
    if (password.length < 6) {
      _passwordStrengthText = "Sehr schwach (min. 6 Zeichen)";
      _passwordStrengthColor = Colors.red;
    } else {
      score++; // Länge > 6

      if (password.length >= 8) score++; // Länger als 8 Zeichen
      if (RegExp(r'[A-Z]').hasMatch(password)) score++; // Großbuchstaben
      if (RegExp(r'[a-z]').hasMatch(password)) score++; // Kleinbuchstaben
      if (RegExp(r'\d').hasMatch(password)) score++; // Zahlen
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++; // Sonderzeichen

      if (score < 3) {
        _passwordStrengthText = "Schwach";
        _passwordStrengthColor = Colors.orange;
      } else if (score < 5) {
        _passwordStrengthText = "Mittel";
        _passwordStrengthColor = Colors.yellow;
      } else {
        _passwordStrengthText = "Stark";
        _passwordStrengthColor = Colors.green;
      }
    }
    setState(() {}); // UI aktualisieren
  }

  void _register() async {
    setState(() => _loading = true);

    if (_pw.text.trim() != _confirmPw.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Passwörter stimmen nicht überein!'),
      ));
      setState(() => _loading = false);
      return;
    }

    if (_passwordStrengthColor == Colors.red || _passwordStrengthText == "Sehr schwach (min. 6 Zeichen)") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte wähle ein stärkeres Passwort (mindestens 6 Zeichen).'),
      ));
      setState(() => _loading = false);
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pw.text.trim());
      await credential.user!.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Registrierung erfolgreich! Bitte bestätige deine E-Mail-Adresse und melde dich dann an.')),
      );
      widget.onSwitch(); // Zurück zum Login-Formular
    } on FirebaseAuthException catch (e) {
      String msg = 'Fehler bei der Registrierung.';
      if (e.code == 'weak-password') {
        msg = 'Das Passwort ist zu schwach.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'Diese E-Mail-Adresse ist bereits registriert.';
      } else if (e.code == 'invalid-email') {
        msg = 'Die E-Mail-Adresse ist ungültig.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ein Fehler ist aufgetreten: $e')));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(80),
            ),
            child: Image.asset(
              'assets/login_header.png',
              width: MediaQuery.of(context).size.width,
              height: screenHeight * 0.35,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              color: const Color(0xFF1C1C1C),
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Registrieren',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email, color: Colors.white70),
                        labelText: 'E-Mail',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _pw,
                      style: const TextStyle(color: Colors.white),
                      obscureText: !_pwVisible,
                      onChanged: _checkPasswordStrength, // Passwortstärke prüfen
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                        labelText: 'Passwort',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                            icon: Icon(
                              _pwVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _pwVisible = !_pwVisible)),
                      ),
                    ),
                    // Anzeige der Passwortstärke
                    if (_passwordStrengthText != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            'Stärke: $_passwordStrengthText',
                            style: TextStyle(
                              color: _passwordStrengthColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _confirmPw, // Zweites Passwortfeld
                      style: const TextStyle(color: Colors.white),
                      obscureText: !_confirmPwVisible,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_reset, color: Colors.white70),
                        labelText: 'Passwort wiederholen',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPwVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(() => _confirmPwVisible = !_confirmPwVisible)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Registrieren'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Bereits einen Account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(onPressed: widget.onSwitch, child: const Text("Anmelden"))
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _confirmPw.dispose(); // Wichtig: Auch diesen Controller entsorgen!
    super.dispose();
  }
}


class ProfileForm extends StatefulWidget {
  final User user;
  final VoidCallback onSaved;
  final List<String> missingFields;
  final List<String> requiredFields;
  final Map<String, Color> colorOptions; // Neue Property für Farboptionen

  const ProfileForm({
    super.key,
    required this.user,
    required this.onSaved,
    required this.missingFields,
    required this.requiredFields,
    required this.colorOptions, // Initialisierung im Konstruktor
  });

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _benutzernameController = TextEditingController();
  final TextEditingController _vornameController = TextEditingController();
  final TextEditingController _nachnameController = TextEditingController();
  final TextEditingController _plzController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  DateTime? _geburtsdatum;
  String? _selectedGender;
  bool _doggyRole = false;
  bool _herrchenRole = false;
  bool _diskretModus = false;
  bool _ageHidden = false;
  String? _profileImageUrl;
  bool _loading = false;
  String? _selectedFavoriteColor; // Neues Feld für die Lieblingsfarbe

  // NEU: Map zur Übersetzung von Firestore-Keys in lesbare Namen für die UI.
  final Map<String, String> _fieldDisplayNames = {
    'benutzername': 'Benutzername',
    'vorname': 'Vorname',
    'nachname': 'Nachname',
    'geburtsdatum': 'Geburtsdatum',
    'gender': 'Geschlecht',
    'roles': 'Rolle'
  };

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
    final data = doc.data();

    if (data != null) {
      _benutzernameController.text = data['benutzername'] ?? '';
      _vornameController.text = data['vorname'] ?? '';
      _nachnameController.text = data['nachname'] ?? '';
      _plzController.text = data['plz'] ?? '';
      _cityController.text = data['city'] ?? '';

      if (data['geburtsdatum'] != null) {
        _geburtsdatum = (data['geburtsdatum'] as Timestamp).toDate();
      }
      _selectedGender = data['gender'];
      _doggyRole = (data['roles'] as List<dynamic>).contains('doggy');
      _herrchenRole = (data['roles'] as List<dynamic>).contains('herrchen');
      _diskretModus = data['diskretModus'] ?? false;
      _ageHidden = data['ageHidden'] ?? false;
      _profileImageUrl = data['profileImageUrl'];
      _selectedFavoriteColor = data['favoriteColor']; // Lieblingsfarbe laden
      // PIN wird nicht direkt geladen, da nur der Hash gespeichert wird
    }
    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _loading = true);
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${widget.user.uid}.jpg');
        await storageRef.putFile(File(image.path));
        final imageUrl = await storageRef.getDownloadURL();
        setState(() {
          _profileImageUrl = imageUrl;
        });
        // Speichern der URL in Firestore
        await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
          'profileImageUrl': imageUrl,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilbild erfolgreich hochgeladen!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen des Bildes: $e')),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _geburtsdatum ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _geburtsdatum) {
      setState(() {
        _geburtsdatum = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_doggyRole && !_herrchenRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle mindestens eine Rolle aus (Doggy oder Herrchen).')),
      );
      return;
    }

    if (_diskretModus && _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib eine PIN für den diskreten Modus ein.')),
      );
      return;
    }
    if (_diskretModus && _pinController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Die PIN muss 6 Ziffern lang sein.')),
      );
      return;
    }


    setState(() => _loading = true);
    List<String> roles = [];
    if (_doggyRole) roles.add('doggy');
    if (_herrchenRole) roles.add('herrchen');

    String pinHash = '';
    if (_diskretModus && _pinController.text.isNotEmpty) {
      pinHash = sha256hash(_pinController.text.trim());
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'benutzername': _benutzernameController.text.trim(),
        'vorname': _vornameController.text.trim(),
        'nachname': _nachnameController.text.trim(),
        'geburtsdatum': _geburtsdatum != null ? Timestamp.fromDate(_geburtsdatum!) : null,
        'gender': _selectedGender,
        'roles': roles,
        'diskretModus': _diskretModus,
        'pinHash': pinHash,
        'ageHidden': _ageHidden,
        'plz': _plzController.text.trim(),
        'city': _cityController.text.trim(),
        'favoriteColor': _selectedFavoriteColor, // Lieblingsfarbe speichern
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil erfolgreich gespeichert!')),
      );
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern des Profils: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // KORREKTUR: Validierungsfunktionen verwenden die _fieldDisplayNames Map für
  // benutzerfreundliche Fehlermeldungen.
  String? _validateRequired(String? value, String fieldName) {
    if (widget.missingFields.contains(fieldName) && (value == null || value.isEmpty)) {
      final displayName = _fieldDisplayNames[fieldName] ?? fieldName;
      return '$displayName ist erforderlich.';
    }
    return null;
  }

  String? _validateRequiredDate(DateTime? value, String fieldName) {
    if (widget.missingFields.contains(fieldName) && value == null) {
      final displayName = _fieldDisplayNames[fieldName] ?? fieldName;
      return '$displayName ist erforderlich.';
    }
    return null;
  }

  String? _validateRequiredRole() {
    if (widget.missingFields.contains('roles') && !_doggyRole && !_herrchenRole) {
      return 'Mindestens eine Rolle (Doggy/Herrchen) ist erforderlich.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // KORREKTUR: Erzeuge eine lesbare Liste der fehlenden Felder für die UI.
    final missingFieldDisplayNames = widget.missingFields
        .map((field) => _fieldDisplayNames[field] ?? field)
        .join(', ');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenHeight * 0.05), // Abstand von oben

              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white10,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white70,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.orange, size: 30),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Profil vervollständigen',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (widget.missingFields.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    // KORREKTUR: Verwende die lesbare Liste.
                    'Bitte fülle die folgenden fehlenden Felder aus: $missingFieldDisplayNames',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextFormField(
                controller: _benutzernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Benutzername'),
                validator: (value) => _validateRequired(value, 'benutzername'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vornameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Vorname'),
                validator: (value) => _validateRequired(value, 'vorname'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nachnameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nachname'),
                validator: (value) => _validateRequired(value, 'nachname'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _geburtsdatum == null
                          ? 'Geburtsdatum'
                          : 'Geburtsdatum: ${_geburtsdatum!.toLocal().toIso8601String().split('T')[0]}',
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                    ),
                    validator: (value) => _validateRequiredDate(_geburtsdatum, 'geburtsdatum'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: const Color(0xFF1C1C1C),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Geschlecht'),
                items: ['Männlich', 'Weiblich', 'Divers', 'Möchte ich nicht angeben']
                    .map((String gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
                
                validator: (value) => _validateRequired(value, 'gender'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plzController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Postleitzahl'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Stadt'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // NEU: Lieblingsfarbe Dropdown
              DropdownButtonFormField<String>(
                value: _selectedFavoriteColor,
                dropdownColor: const Color(0xFF1C1C1C),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Lieblingsfarbe (Optional)',
                  hintText: 'Wähle deine Lieblingsfarbe',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Keine Auswahl', style: TextStyle(color: Colors.white70)),
                  ),
                  ...widget.colorOptions.keys.map((String colorName) {
                    return DropdownMenuItem<String>(
                      value: colorName,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            color: widget.colorOptions[colorName],
                          ),
                          const SizedBox(width: 10),
                          Text(colorName),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFavoriteColor = newValue;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text('Rollen:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text('Doggy (oder Streuner)', style: TextStyle(color: Colors.white)),
                value: _doggyRole,
                onChanged: (bool? value) {
                  setState(() {
                    _doggyRole = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Theme.of(context).colorScheme.primary, // Dynamische Farbe
                checkColor: Colors.black,
              ),
              CheckboxListTile(
                title: const Text('Herrchen', style: TextStyle(color: Colors.white)),
                value: _herrchenRole,
                onChanged: (bool? value) {
                  setState(() {
                    _herrchenRole = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Theme.of(context).colorScheme.primary, // Dynamische Farbe
                checkColor: Colors.black,
              ),
              if (_validateRequiredRole() != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                  child: Text(
                    _validateRequiredRole()!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _ageHidden,
                    fillColor: MaterialStateProperty.all(Theme.of(context).colorScheme.secondary), // Dynamische Farbe
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => _ageHidden = v ?? false),
                  ),
                  const Text("Alter im Profil verstecken", style: TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _diskretModus,
                    fillColor: MaterialStateProperty.all(Theme.of(context).colorScheme.secondary), // Dynamische Farbe
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => _diskretModus = v ?? false),
                  ),
                  const Text("Diskreter Modus (App mit PIN sichern)", style: TextStyle(color: Colors.white)),
                ],
              ),
              if (_diskretModus)
                TextField(
                  controller: _pinController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: "PIN (6-stellig)"),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Text("Profil speichern"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _benutzernameController.dispose();
    _vornameController.dispose();
    _nachnameController.dispose();
    _plzController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
