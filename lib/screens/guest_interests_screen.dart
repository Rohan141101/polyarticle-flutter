import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';

const _interests = [
  'Business 💼',
  'Crypto 🪙',
  'Entertainment 🎬',
  'General 📰',
  'Health 🏥',
  'Politics 🏛️',
  'Sports ⚽',
  'Stocks 📈',
  'Technology 💻',
  'World 🌍',
];

class GuestInterestsScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const GuestInterestsScreen({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<GuestInterestsScreen> createState() => _GuestInterestsScreenState();
}

class _GuestInterestsScreenState extends State<GuestInterestsScreen> {
  final Set<String> _selected = {};
  String? _error;

  void _next() {
    if (_selected.isEmpty) {
      setState(() => _error = 'Please select at least one interest');
      return;
    }
    context.read<GuestProvider>().saveInterests(_selected.toList());
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().darkMode;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF888888) : Colors.grey;
    final chipBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final chipBorder =
        isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD);
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedText = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Text('← Back',
                    style: TextStyle(color: subColor, fontSize: 14)),
              ),
              const SizedBox(height: 24),
              Text(
                'Your interests',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select topics you care about',
                style: TextStyle(fontSize: 15, color: subColor),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 14)),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _interests.map((interest) {
                  final selected = _selected.contains(interest);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selected.remove(interest);
                        } else {
                          _selected.add(interest);
                        }
                        _error = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? selectedBg : chipBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected ? selectedBg : chipBorder,
                        ),
                      ),
                      child: Text(
                        interest,
                        style: TextStyle(
                          color: selected ? selectedText : textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Next',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
