// DoggyShopScreen: zeigt verfügbare Belohnungen basierend auf Doggy-Namen

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoggyShopScreen extends StatefulWidget {
  final String doggyName;

  const DoggyShopScreen({super.key, required this.doggyName});

  @override
  State<DoggyShopScreen> createState() => _DoggyShopScreenState();
}

class _DoggyShopScreenState extends State<DoggyShopScreen> {
  List<Map<String, dynamic>> _allRewards = [];
  List<Map<String, dynamic>> _availableRewards = [];
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final rewardList = prefs.getString('shop_items');
    final currentPoints = prefs.getInt('points_${widget.doggyName}') ?? 0;

    if (rewardList != null) {
      final rewards = List<Map<String, dynamic>>.from(jsonDecode(rewardList));
      final filtered = rewards.where((r) => r['doggy'] == 'Alle' || r['doggy'] == widget.doggyName).toList();
      setState(() {
        _allRewards = rewards;
        _availableRewards = filtered.where((r) => r['active'] == true).toList();
        _points = currentPoints;
      });
    }
  }

  void _redeemReward(Map<String, dynamic> reward) async {
    final int cost = (reward['points'] ?? 0) as int;
    if (_points >= cost) {
      setState(() => _points -= cost);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('points_${widget.doggyName}', _points);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${reward['title']}" eingelöst!')),
      );

      // Optional: Nutzung mitzählen & Preis eskalieren
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nicht genug Punkte!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shop für ${widget.doggyName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Verfügbare Punkte: $_points', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: _availableRewards.isEmpty
                  ? const Text('Keine Belohnungen verfügbar.')
                  : ListView.builder(
                      itemCount: _availableRewards.length,
                      itemBuilder: (_, index) {
                        final reward = _availableRewards[index];
                        return Card(
                          child: ListTile(
                            title: Text(reward['title']),
                            subtitle: Text('${reward['description']}\nKosten: ${reward['points']} Punkte'),
                            trailing: ElevatedButton(
                              onPressed: () => _redeemReward(reward),
                              child: const Text('Einlösen'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
