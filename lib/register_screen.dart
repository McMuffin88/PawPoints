import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verify_email_screen.dart';
import 'doggy_screen.dart'; // Optional für Test-Button
import 'main.dart'; // Für StartupScreen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // 🔒 Name und E-Mail speichern
      final prefs = await SharedPreferences.getInstance();
// KEIN displayname hier speichern – der kommt später
await prefs.setString('herrchen_email', _emailController.text);


      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            username: _usernameController.text,
            email: _emailController.text,
          ),
        ),
      );
    }
  }

  Future<void> _goBackToStartup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role'); // Rolle zurücksetzen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StartupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Herrchen Registrierung'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToStartup,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
    const SizedBox(height: 20),

    // 👇 Logo
Center(
  child: Image.asset(
    'assets/logo.png',
    height: 100,
    errorBuilder: (context, error, stackTrace) {
      return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
    },
  ),
),


    const SizedBox(height: 24),

    const Text(
      "Erstelle dein Herrchen-Konto",
      style: TextStyle(fontSize: 20),
      textAlign: TextAlign.center,
    ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Benutzername'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Bitte angeben' : null,
              ),
              const SizedBox(height: 16),
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
                onPressed: _submit,
                child: const Text('Registrieren'),
              ),
              const SizedBox(height: 24),

              // 👇 Testzugang zum Doggy-Screen
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoggyScreen()),
                  );
                },
                child: const Text('Zum Doggy-Bereich (Test)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
