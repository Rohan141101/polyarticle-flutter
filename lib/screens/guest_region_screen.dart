import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';

const _regions = [
  'USA', 'UK', 'Australia', 'Canada', 'India',
  'Germany', 'France', 'Japan', 'Brazil', 'South Africa', 'UAE', 'Singapore',
];

class GuestRegionScreen extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onBack;

  const GuestRegionScreen({
    super.key,
    required this.onDone,
    required this.onBack,
  });

  @override
  State<GuestRegionScreen> createState() => _GuestRegionScreenState();
}

class _GuestRegionScreenState extends State<GuestRegionScreen> {
  String _selected = _regions.first;
  bool _loading = false;

  Future<void> _done() async {
    setState(() => _loading = true);
    final guest = context.read<GuestProvider>();
    await guest.saveRegion(_selected);
    await guest.completeSetup();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().darkMode;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF888888) : Colors.grey;
    final borderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE);

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
                'Your region',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your location for regional news',
                style: TextStyle(fontSize: 15, color: subColor),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selected,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    style: TextStyle(color: textColor, fontSize: 15),
                    onChanged: (val) {
                      if (val != null) setState(() => _selected = val);
                    },
                    items: _regions
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: Colors.grey[600],
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Get Started',
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
