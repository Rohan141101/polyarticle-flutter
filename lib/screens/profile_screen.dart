import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api.dart' as api;

const _locations = [
  'USA',
  'UK',
  'Australia',
  'Canada',
  'India',
  'Germany',
  'France',
  'Japan',
  'Brazil',
  'South Africa',
  'UAE',
  'Singapore',
];

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onActiveSessions;
  final VoidCallback? onLogin;
  final VoidCallback? onSignup;

  const ProfileScreen({
    super.key,
    required this.onBack,
    required this.onActiveSessions,
    this.onLogin,
    this.onSignup,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _locationLoading = false;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _selectedLocation = user?.location;
    if (_selectedLocation == null || !_locations.contains(_selectedLocation)) {
      _selectedLocation = _locations.first;
    }
  }

  Future<void> _updateLocation(String location) async {
    setState(() => _locationLoading = true);
    try {
      await api.updateLocation(location);
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
        setState(() => _selectedLocation = location);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to update location: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final uri = Uri.parse('https://polyarticle.com/delete-account.html');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openContactUs() async {
    final uri = Uri.parse('https://polyarticle.com/contact.html');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guest = context.watch<GuestProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.darkMode;
    final user = auth.user;
    final isGuest = Platform.isIOS && guest.isGuest && !auth.isAuthenticated;

    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor = isDark ? Colors.grey[800]! : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Icon(Icons.arrow_back, color: textColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Guest banner
              if (isGuest) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Browsing as Guest',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Create an account to save your preferences.',
                            style:
                                TextStyle(color: subColor, fontSize: 13)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.onSignup,
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Sign Up',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.onLogin,
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Log In',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Account section (only for logged-in users)
              if (!isGuest) ...[
                _sectionLabel('Account', subColor),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.email_outlined, user?.email ?? '—',
                          textColor, divColor),
                      _divider(divColor),
                      _infoRow(Icons.phone_outlined, 'Phone number',
                          subColor, divColor),
                      _divider(divColor),
                      _infoRow(Icons.bookmark_outline, 'Saved articles',
                          subColor, divColor),
                      _divider(divColor),
                      _buttonRow(
                        icon: Icons.lock_outline,
                        label: 'Change password',
                        textColor: textColor,
                        divColor: divColor,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Coming Soon'),
                              content: const Text(
                                  'Password change coming soon!'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      _divider(divColor),
                      _buttonRow(
                        icon: Icons.devices,
                        label: 'Active Sessions',
                        textColor: textColor,
                        divColor: divColor,
                        onTap: widget.onActiveSessions,
                      ),
                      _divider(divColor),
                      _buttonRow(
                        icon: Icons.delete_outline,
                        label: 'Delete Account',
                        textColor: Colors.red,
                        divColor: divColor,
                        onTap: _handleDeleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Preferences section (always shown)
              _sectionLabel('Preferences', subColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _switchRow(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark Mode',
                      value: isDark,
                      textColor: textColor,
                      divColor: divColor,
                      onChanged: settings.setDarkMode,
                    ),
                    _divider(divColor),
                    _switchRow(
                      icon: Icons.vibration,
                      label: 'Haptics',
                      value: settings.haptics,
                      textColor: textColor,
                      divColor: divColor,
                      onChanged: settings.setHaptics,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Location section
              _sectionLabel('Location', subColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: textColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLocation,
                            isExpanded: true,
                            style: TextStyle(
                                color: textColor, fontSize: 15),
                            dropdownColor: cardBg,
                            onChanged: _locationLoading
                                ? null
                                : (val) {
                                    if (val != null) _updateLocation(val);
                                  },
                            items: _locations
                                .map((l) => DropdownMenuItem(
                                    value: l, child: Text(l)))
                                .toList(),
                          ),
                        ),
                      ),
                      if (_locationLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Contact section
              _sectionLabel('Contact', subColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined,
                              color: textColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'hello@polyarticle.com',
                              style:
                                  TextStyle(color: textColor, fontSize: 15),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(
                                  text: 'hello@polyarticle.com'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email copied!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Icon(Icons.copy,
                                color: subColor, size: 18),
                          ),
                        ],
                      ),
                    ),
                    _divider(divColor),
                    _buttonRow(
                      icon: Icons.message_outlined,
                      label: 'Send us a message',
                      textColor: textColor,
                      divColor: divColor,
                      onTap: _openContactUs,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 28, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _divider(Color color) {
    return Divider(height: 1, color: color, indent: 16, endIndent: 0);
  }

  Widget _infoRow(
      IconData icon, String label, Color textColor, Color divColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textColor, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buttonRow({
    required IconData icon,
    required String label,
    required Color textColor,
    required Color divColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(color: textColor, fontSize: 15))),
            Icon(Icons.chevron_right, color: textColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required Color textColor,
    required Color divColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: textColor, fontSize: 15))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
