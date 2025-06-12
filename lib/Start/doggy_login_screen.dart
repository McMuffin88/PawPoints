// DoggyLoginScreen – mit Verifizierungs- und Profildatenprüfung
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'doggy_profile_setup_screen.dart';
import '/doggy_screen.dart';
import 'verify_email_screen.dart';

class DoggyLoginScreen extends StatefulWidget {
  const DoggyLoginScreen({super.key});

  @override
  State<DoggyLoginScreen> createState() => _DoggyLoginScreenState();
}

class _DoggyLoginScreenState extends State<DoggyLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte bestätige deine E-Mail – wir haben dir eine geschickt.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              username: email.split('@').first,
              email: email,
            ),
          ),
        );
        return;
      }

      // 🔍 Prüfen ob Profildaten vollständig sind
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists || !(doc.data()?['name']?.toString().isNotEmpty ?? false)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DoggyProfileSetupScreen(withoutHerrchen: false),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DoggyScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Fehler beim Einloggen')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doggy Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Willkommen zurück 🐶',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val != null && val.contains('@')
                      ? null
                      : 'Gültige E-Mail eingeben',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Passwort'),
                  obscureText: true,
                  validator: (val) => val != null && val.length >= 6
                      ? null
                      : 'Mindestens 6 Zeichen',
                ),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Einloggen'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
