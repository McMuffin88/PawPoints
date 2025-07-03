import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchriftgroesseProvider extends ChangeNotifier {
  double allgemeineSchriftgroesse;
  double buttonSchriftgroesse;

  SchriftgroesseProvider({
    this.allgemeineSchriftgroesse = 16.0,
    this.buttonSchriftgroesse = 18.0,
  }) {
    _loadFromPrefs();
  }

  void setAllgemeineSchriftgroesse(double value) {
    allgemeineSchriftgroesse = value;
    _saveToPrefs();
    notifyListeners();
  }

  void setButtonSchriftgroesse(double value) {
    buttonSchriftgroesse = value;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    allgemeineSchriftgroesse = prefs.getDouble('allgemeineSchriftgroesse') ?? 16.0;
    buttonSchriftgroesse = prefs.getDouble('buttonSchriftgroesse') ?? 18.0;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('allgemeineSchriftgroesse', allgemeineSchriftgroesse);
    await prefs.setDouble('buttonSchriftgroesse', buttonSchriftgroesse);
  }
}
