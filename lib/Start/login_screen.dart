import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../herrchen_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = FirebaseAuth.instance;

        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = auth.currentUser;
        await user?.reload();

        if (user != null && !user.emailVerified) {
          // 12h-Limit prüfen
          final prefs = await SharedPreferences.getInstance();
          final lastSent = prefs.getInt('last_verification_sent') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          final interval = const Duration(hours: 12).inMilliseconds;


          if (now - lastSent > interval) {
            await user.sendEmailVerification();
            await prefs.setInt('last_verification_sent', now);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verifizierungs-E-Mail wurde erneut gesendet'),
              ),
            );
          }

          // Weiterleitung zur Verifizierungsseite
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(
                username: user.email!.split('@')[0],
                email: user.email!,
              ),
            ),
          );

          return; // nicht weiter zur HerrchenScreen
        }

        // Wenn verifiziert: Login OK
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'herrchen');
        await prefs.setString('herrchen_email', _emailController.text);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HerrchenScreen()),
        );
      } on FirebaseAuthException catch (e) {
        String message = 'Anmeldung fehlgeschlagen';

        if (e.code == 'user-not-found') {
          message = 'Kein Benutzer mit dieser E-Mail gefunden';
        } else if (e.code == 'wrong-password') {
          message = 'Falsches Passwort';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anmeldung')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Melde dich an",
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Gültige E-Mail eingeben'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                validator: (value) =>
                    value == null || value.length < 6
                        ? 'Mind. 6 Zeichen'
                        : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Einloggen'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Noch kein Konto?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text("Jetzt registrieren"),
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
