import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';

import 'doggy_screen.dart';
import 'herrchen_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const PawPointsApp());
}

class PawPointsApp extends StatelessWidget {
  const PawPointsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawPoints',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', ''),
        Locale('en', ''),
      ],
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool showLogin = true;
  bool loading = false;
  User? _user;
  bool _showProfileForm = false;
  Map<String, dynamic>? _profileData;
  List<String> _missingFields = [];

  final List<String> requiredProfileFields = [
    'benutzername',
    'vorname',
    'nachname',
    'geburtsdatum',
    'gender',
    'roles',
  ];

  @override
  void initState() {
    super.initState();
    _checkAppVersion();
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

  void _showUpdateDialog(String url) {
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
              if (await canLaunchUrlString(url)) {
                await launchUrlString(url);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Jetzt aktualisieren'),
          ),
        ],
      ),
    );
  }

  void toggle() => setState(() => showLogin = !showLogin);

  Future<void> _afterLogin(User user) async {
    setState(() => loading = true);
    await user.reload();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutzer konnte nicht gefunden werden!')));
      return;
    }

    if (!currentUser.emailVerified) {
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

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    setState(() {
      loading = false;
      _user = currentUser;
      _profileData = userDoc.data();
    });

    if (!userDoc.exists) {
      _missingFields = List.from(requiredProfileFields);
      setState(() => _showProfileForm = true);
      return;
    }

    _missingFields = [];
    for (var field in requiredProfileFields) {
      if (_profileData == null ||
          !_profileData!.containsKey(field) ||
          _profileData![field] == null ||
          _profileData![field].toString().isEmpty) {
        _missingFields.add(field);
      }
    }

    if (_missingFields.isNotEmpty) {
      setState(() => _showProfileForm = true);
      return;
    }

    final roles = List<String>.from(_profileData?['roles'] ?? []);
    if (roles.contains('doggy')) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DoggyScreen()));
    } else if (roles.contains('herrchen')) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HerrchenScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bitte wähle im Profil mindestens eine Rolle aus!')));
      setState(() => _showProfileForm = true);
    }
  }

  void _onProfileSaved() {
    setState(() {
      _showProfileForm = false;
      _missingFields = [];
    });
    if (_profileData == null) return;
    final roles = List<String>.from(_profileData?['roles'] ?? []);
    if (roles.contains('doggy')) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DoggyScreen()));
    } else if (roles.contains('herrchen')) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HerrchenScreen()));
    }
  }

  Future<bool> _onWillPop() async {
    if (!Platform.isAndroid) return true;
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
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', height: 160),
                      const SizedBox(height: 24),
                      if (_showProfileForm && _user != null)
                        ProfileForm(
                          user: _user!,
                          onSaved: () async {
                            final doc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_user!.uid)
                                .get();
                            _profileData = doc.data();
                            _onProfileSaved();
                          },
                          missingFields: _missingFields,
                          requiredFields: requiredProfileFields,
                        )
                      else if (showLogin)
                        LoginForm(onSwitch: toggle, onSuccess: _afterLogin)
                      else
                        RegisterForm(onSwitch: toggle),
                    ],
                  ),
                ),
              ),
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
    final emailRegex = RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (emailRegex.hasMatch(input.trim())) {
      return input.trim(); // Email direkt
    } else {
      // Benutzername -> Email via Cloud Function
      try {
final result = await FirebaseFunctions.instance
  .httpsCallable('usernameToEmail')
  .call({'username': _loginInput.text.trim()});
        return result.data['email'] as String;
      } catch (e) {
        throw Exception('Benutzername nicht gefunden');
      }
    }
  }

  void _login() async {
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
      setState(() => _loading = false);
      String msg = 'Fehler beim Login: $e';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            msg = 'Kein Nutzer mit dieser E-Mail gefunden!';
            break;
          case 'wrong-password':
            msg = 'Falsches Passwort!';
            break;
          case 'invalid-email':
            msg = 'Bitte gib eine gültige E-Mail-Adresse ein.';
            break;
          case 'user-disabled':
            msg = 'Dieser Nutzer wurde deaktiviert.';
            break;
          case 'too-many-requests':
            msg = 'Zu viele Anmeldeversuche. Bitte später versuchen.';
            break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Willkommen zurück',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Melde dich mit Benutzername oder E-Mail an'),
            const SizedBox(height: 18),
            TextField(
              controller: _loginInput,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Benutzername oder E-Mail'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: !_pwVisible,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  labelText: 'Passwort',
                  suffixIcon: IconButton(
                      icon: Icon(
                          _pwVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _pwVisible = !_pwVisible))),
            ),
            Row(
              children: [
                Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false)),
                const Text('Angemeldet bleiben'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child:
                    _loading ? const CircularProgressIndicator() : const Text('Anmelden'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Noch keinen Account? "),
                  GestureDetector(
                    onTap: widget.onSwitch,
                    child: const Text("Registrieren",
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ])
          ]),
        ));
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
  bool _pwVisible = false;
  bool _loading = false;

  void _register() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pw.text.trim());
      await cred.user?.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Registrierung erfolgreich! Bitte bestätige deine E-Mail-Adresse.'),
        duration: Duration(seconds: 6),
      ));
      widget.onSwitch();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Diese E-Mail ist bereits vergeben!';
          break;
        case 'invalid-email':
          msg = 'Bitte gib eine gültige E-Mail-Adresse ein.';
          break;
        case 'weak-password':
          msg = 'Das Passwort ist zu schwach. Es muss mindestens 6 Zeichen lang sein.';
          break;
        case 'operation-not-allowed':
          msg = 'Registrierung ist momentan nicht erlaubt.';
          break;
        default:
          msg = 'Fehler: ${e.message ?? e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unbekannter Fehler: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Registrieren',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "E-Mail")),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: !_pwVisible,
              decoration: InputDecoration(
                  labelText: 'Passwort',
                  suffixIcon: IconButton(
                      icon: Icon(
                          _pwVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _pwVisible = !_pwVisible))),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text("Registrieren"),
              ),
            ),
            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Schon registriert? "),
                  GestureDetector(
                    onTap: widget.onSwitch,
                    child: const Text("Anmelden",
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ])
          ]),
        ));
  }
}

// ---- PROFILE FORM (mit Profilbild, Tooltips etc.) ----
class ProfileForm extends StatefulWidget {
  final User user;
  final VoidCallback onSaved;
  final List<String> missingFields;
  final List<String> requiredFields;

  const ProfileForm(
      {super.key,
      required this.user,
      required this.onSaved,
      required this.missingFields,
      required this.requiredFields});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _benutzername = TextEditingController();
  final _vorname = TextEditingController();
  final _nachname = TextEditingController();
  DateTime? _geburtsdatum;
  String _gender = 'männlich';
  final List<String> _roles = [];
  final _plz = TextEditingController();
  final _city = TextEditingController();
  bool _diskretModus = false;
  final _pin = TextEditingController();
  bool _loading = false;
  bool _ageHidden = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    // Falls gewünscht, lade hier Profildaten vor (z.B. aus widget.missingFields)
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = widget.user;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

    String url;
    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      await ref.putData(bytes);
      url = await ref.getDownloadURL();
    } else {
      final file = File(pickedFile.path);
      await ref.putFile(file);
      url = await ref.getDownloadURL();
    }

    setState(() => _profileImageUrl = url);
  }

  Future<void> _pickGeburtsdatum(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('de', ''),
    );
    if (picked != null) setState(() => _geburtsdatum = picked);
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Widget infoIcon(String message) => Tooltip(
        message: message,
        child: Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
        ),
      );

  void _showMissingFieldsHint() {
    final buffer = StringBuffer();
    buffer.writeln('Folgende Felder fehlen:');
    for (final field in widget.missingFields) {
      buffer.writeln('- $field');
    }
    buffer.writeln(
        '\nAb Version XX werden diese Daten für eine bessere Nutzererfahrung benötigt.');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil unvollständig'),
        content: Text(buffer.toString()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _saveProfile() async {
    setState(() => _loading = true);

    for (final field in widget.requiredFields) {
      switch (field) {
        case 'benutzername':
          if (_benutzername.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte Benutzername angeben!')));
            setState(() => _loading = false);
            return;
          }
          break;
        case 'vorname':
          if (_vorname.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte Vorname angeben!')));
            setState(() => _loading = false);
            return;
          }
          break;
        case 'nachname':
          if (_nachname.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte Nachname angeben!')));
            setState(() => _loading = false);
            return;
          }
          break;
        case 'geburtsdatum':
          if (_geburtsdatum == null) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte Geburtsdatum angeben!')));
            setState(() => _loading = false);
            return;
          }
          final age = _calculateAge(_geburtsdatum!);
          if (age < 18) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Du musst mindestens 18 Jahre alt sein, um dich zu registrieren.')));
            setState(() => _loading = false);
            return;
          }
          break;
        case 'gender':
          break;
        case 'roles':
          if (_roles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bitte wähle mindestens eine Rolle aus!')));
            setState(() => _loading = false);
            return;
          }
          break;
      }
    }

    final age = _geburtsdatum != null ? _calculateAge(_geburtsdatum!) : null;

    final userData = {
      'uid': widget.user.uid,
      'benutzername': _benutzername.text.trim(),
      'vorname': _vorname.text.trim(),
      'nachname': _nachname.text.trim(),
      'email': widget.user.email,
      'geburtsdatum': _geburtsdatum,
      'age': age,
      'ageHidden': _ageHidden,
      'gender': _gender,
      'plz': _plz.text.trim(),
      'city': _city.text.trim(),
      'roles': _roles,
      'diskretModus': _diskretModus,
      'pinHash': _diskretModus ? _pin.text.trim() : "",
      'doggyIds': <String>[],
      'herrchenIds': <String>[],
      'premium': {'doggy': false, 'herrchen': false},
      'profileImageUrl': _profileImageUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set(userData);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil erfolgreich gespeichert!')));
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      final data = doc.data();
      final roles = List<String>.from(data?['roles'] ?? []);
      if (roles.contains('doggy')) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DoggyScreen()));
      } else if (roles.contains('herrchen')) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HerrchenScreen()));
      } else {
        widget.onSaved();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern des Profils: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final age = _geburtsdatum != null ? _calculateAge(_geburtsdatum!) : null;
    ImageProvider? imageProvider;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(_profileImageUrl!);
    }
    return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Profildaten vervollständigen',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                if (widget.missingFields.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: ElevatedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Warum Profildaten vervollständigen?'),
                        onPressed: _showMissingFieldsHint),
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 52,
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? const Icon(Icons.person, size: 52)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text("Profilbild hochladen",
                    style: TextStyle(color: Colors.blue)),
                const SizedBox(height: 14),
                TextField(
                  controller: _benutzername,
                  decoration: const InputDecoration(
                      labelText: "Benutzername",
                      hintText: "Wähle deinen öffentlichen Namen aus"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vorname,
                  decoration: InputDecoration(
                      labelText: "Vorname",
                      suffixIcon: infoIcon("Wird nie für andere Nutzer angezeigt")),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nachname,
                  decoration: InputDecoration(
                      labelText: "Nachname",
                      suffixIcon: infoIcon("Wird nie für andere Nutzer angezeigt")),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _pickGeburtsdatum(context),
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                          labelText: 'Geburtsdatum',
                          hintText: 'TT.MM.JJJJ',
                          suffixIcon:
                              infoIcon("Wird benötigt zur Altersverifikation")),
                      controller: TextEditingController(
                          text: _geburtsdatum == null
                              ? ''
                              : "${_geburtsdatum!.day.toString().padLeft(2, '0')}.${_geburtsdatum!.month.toString().padLeft(2, '0')}.${_geburtsdatum!.year}"),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (age != null)
                  Row(children: [
                    Text("Alter: $age"),
                    const SizedBox(width: 12),
                    Checkbox(
                        value: _ageHidden,
                        onChanged: (v) => setState(() => _ageHidden = v ?? false)),
                    const Text("Alter nicht anzeigen"),
                  ]),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: ["männlich", "weiblich", "divers"]
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _gender = v ?? "männlich"),
                  decoration: const InputDecoration(labelText: "Geschlecht"),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _plz,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: "PLZ (optional)",
                          suffixIcon: infoIcon(
                              "PLZ und Ort sind optional. Für regionale Premium-Suchfunktionen benötigt.")),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _city,
                      decoration: InputDecoration(
                          labelText: "Ort (optional)",
                          suffixIcon: infoIcon(
                              "PLZ und Ort sind optional. Für regionale Premium-Suchfunktionen benötigt.")),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Checkbox(
                      value: _roles.contains('doggy'),
                      onChanged: (v) => setState(() {
                            v == true
                                ? _roles.add('doggy')
                                : _roles.remove('doggy');
                          })),
                  const Text('Doggy'),
                  Checkbox(
                      value: _roles.contains('herrchen'),
                      onChanged: (v) => setState(() {
                            v == true
                                ? _roles.add('herrchen')
                                : _roles.remove('herrchen');
                          })),
                  const Text('Herrchen'),
                ]),
                Row(children: [
                  Checkbox(
                      value: _diskretModus,
                      onChanged: (v) => setState(() => _diskretModus = v ?? false)),
                  const Text("Diskreter Modus (App mit PIN sichern)"),
                ]),
                if (_diskretModus)
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: "PIN (6-stellig)"),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveProfile,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text("Profil speichern"),
                  ),
                ),
              ]),
            )));
  }
}

