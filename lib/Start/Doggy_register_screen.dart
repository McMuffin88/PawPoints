// DoggyRegisterScreen.dart – Registrierung mit E-Mail und Passwort
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pawpoints/Start/verify_email_screen.dart';


class DoggyRegisterScreen extends StatefulWidget {
  const DoggyRegisterScreen({super.key});

  @override
  State<DoggyRegisterScreen> createState() => _DoggyRegisterScreenState();
}

class _DoggyRegisterScreenState extends State<DoggyRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwörter stimmen nicht überein.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte E-Mail-Adresse bestätigen.')),
      );

Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => VerifyEmailScreen(
      username: _emailController.text.trim(), // oder z.B. _emailController.text.split('@').first
      email: _emailController.text.trim(),
    ),
  ),
);


    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registrierung fehlgeschlagen')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrieren als Doggy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                validator: (val) => val == null || !val.contains('@')
                    ? 'Gültige E-Mail angeben'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passwort'),
                validator: (val) => val == null || val.length < 6
                    ? 'Mindestens 6 Zeichen'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passwort bestätigen'),
                validator: (val) => val == null || val.length < 6
                    ? 'Bestätigung eingeben'
                    : null,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Registrieren'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
