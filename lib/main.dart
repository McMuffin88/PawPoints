import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'doggy_screen.dart';
import 'herrchen_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  void toggle() => setState(() => showLogin = !showLogin);

  Future<void> _afterLogin(User user) async {
    setState(() => loading = true);
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final roles = List<String>.from(userDoc.data()?['roles'] ?? []);
    setState(() => loading = false);

    if (roles.contains('doggy')) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoggyScreen()));
    } else if (roles.contains('herrchen')) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HerrchenScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine gültige Rolle gefunden.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', height: 120),
                    const SizedBox(height: 24),
                    showLogin
                        ? LoginForm(onSwitch: toggle, onSuccess: _afterLogin)
                        : RegisterForm(onSwitch: toggle, onSuccess: _afterLogin),
                  ],
                ),
              ),
            ),
          );
  }
}

// ---- LOGIN FORM (Benutzername, Funktions-basiert) ----

class LoginForm extends StatefulWidget {
  final VoidCallback onSwitch;
  final Future<void> Function(User) onSuccess;

  const LoginForm({super.key, required this.onSwitch, required this.onSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _username = TextEditingController();
  final _pw = TextEditingController();
  bool _pwVisible = false;
  bool _rememberMe = false;
  bool _loading = false;

  void _resetPasswordByUsername(BuildContext context) async {
    final usernameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passwort zurücksetzen'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(labelText: 'Benutzername'),
        ),
        actions: [
          TextButton(
            child: const Text('Abbrechen'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('E-Mail senden'),
            onPressed: () async {
              final username = usernameController.text.trim();
              Navigator.pop(ctx);
              if (username.isEmpty) return;
              try {
                await FirebaseFunctions.instance
                    .httpsCallable('sendPasswordResetByUsername')
                    .call({'username': username});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Falls ein Account existiert, wurde eine E-Mail zum Zurücksetzen gesendet.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fehler beim Zurücksetzen: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _login() async {
    setState(() => _loading = true);
    try {
      // 1. Serverseitig E-Mail für Benutzernamen holen
      final result = await FirebaseFunctions.instance
          .httpsCallable('usernameToEmail')
          .call({'username': _username.text.trim()});

      final email = result.data['email'] as String;

      // 2. Login mit E-Mail & Passwort
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _pw.text.trim(),
      );
      await widget.onSuccess(cred.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Login: $e')),
      );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Willkommen zurück', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Melde dich mit deinem Benutzernamen an'),
            const SizedBox(height: 18),
            TextField(
              controller: _username,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Benutzername'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: !_pwVisible,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                labelText: 'Passwort',
                suffixIcon: IconButton(
                  icon: Icon(_pwVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _pwVisible = !_pwVisible),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? false)),
                const Text('Angemeldet bleiben'),
                const Spacer(),
                TextButton(
                  onPressed: () => _resetPasswordByUsername(context),
                  child: const Text('Passwort vergessen?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator() : const Text('Anmelden'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Noch keinen Account? "),
                GestureDetector(
                  onTap: widget.onSwitch,
                  child: const Text("Registrieren", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- REGISTRATION FORM ----

class RegisterForm extends StatefulWidget {
  final VoidCallback onSwitch;
  final Future<void> Function(User) onSuccess;

  const RegisterForm({super.key, required this.onSwitch, required this.onSuccess});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _plz = TextEditingController();
  final _city = TextEditingController();
  String _gender = 'männlich';
  List<String> _roles = [];
  bool _diskretModus = false;
  final _pin = TextEditingController();

  bool _loading = false;
  bool _pwVisible = false;

  Future<bool> _isUsernameUnique(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return result.docs.isEmpty;
  }

  void _register() async {
    setState(() => _loading = true);

    if (!await _isUsernameUnique(_username.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Benutzername ist bereits vergeben!')));
      setState(() => _loading = false);
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text.trim(),
      );
      final userDoc = {
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'name': _name.text.trim(),
        'age': int.tryParse(_age.text.trim()) ?? 0,
        'gender': _gender,
        'plz': _plz.text.trim(),
        'city': _city.text.trim(),
        'roles': _roles,
        'diskretModus': _diskretModus,
        'pinHash': _diskretModus ? _pin.text.trim() : "",
        'doggyIds': <String>[],
        'herrchenIds': <String>[],
        'premium': {'doggy': false, 'herrchen': false},
        'profileImageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(userDoc);

      await widget.onSuccess(cred.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler bei der Registrierung: $e')));
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Registrieren', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(controller: _username, decoration: const InputDecoration(labelText: "Benutzername")),
              const SizedBox(height: 12),
              TextField(controller: _email, decoration: const InputDecoration(labelText: "E-Mail")),
              const SizedBox(height: 12),
              TextField(
                controller: _pw,
                obscureText: !_pwVisible,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  suffixIcon: IconButton(
                    icon: Icon(_pwVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _pwVisible = !_pwVisible),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
              const SizedBox(height: 12),
              TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Alter")),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                items: ["männlich", "weiblich", "divers"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v ?? "männlich"),
                decoration: const InputDecoration(labelText: "Geschlecht"),
              ),
              const SizedBox(height: 12),
              TextField(controller: _plz, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "PLZ")),
              const SizedBox(height: 12),
              TextField(controller: _city, decoration: const InputDecoration(labelText: "Ort")),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _roles.contains('doggy'),
                    onChanged: (v) => setState(() {
                      v == true ? _roles.add('doggy') : _roles.remove('doggy');
                    }),
                  ),
                  const Text('Doggy'),
                  Checkbox(
                    value: _roles.contains('herrchen'),
                    onChanged: (v) => setState(() {
                      v == true ? _roles.add('herrchen') : _roles.remove('herrchen');
                    }),
                  ),
                  const Text('Herrchen'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _diskretModus,
                    onChanged: (v) => setState(() => _diskretModus = v ?? false),
                  ),
                  const Text("Diskreter Modus (App mit PIN sichern)"),
                ],
              ),
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
                    child: const Text("Anmelden", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
