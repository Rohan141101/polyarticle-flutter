import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../services/api.dart' as api;
import '../providers/auth_provider.dart';
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

const _regions = [
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

class SignupScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SignupScreen({super.key, required this.onBack});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 1;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  final Set<String> _selectedInterests = {};
  String _selectedRegion = _regions.first;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _goBack() {
    if (_step == 1) {
      widget.onBack();
    } else {
      setState(() {
        _error = null;
        _step -= 1;
      });
    }
  }

  void _goStep2() {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  void _goStep3() {
    if (_selectedInterests.isEmpty) {
      setState(() => _error = 'Please select at least one interest');
      return;
    }
    setState(() {
      _error = null;
      _step = 3;
    });
  }

  Future<void> _handleSignup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? deviceName;
      String? deviceOS;
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final info = await deviceInfo.androidInfo;
          deviceName = info.model;
          deviceOS = 'Android ${info.version.release}';
        } else if (Platform.isIOS) {
          final info = await deviceInfo.iosInfo;
          deviceName = info.model;
          deviceOS = 'iOS ${info.systemVersion}';
        }
      } catch (_) {}

      // Strip emojis from interest labels to get plain names
      final interests = _selectedInterests.map((i) {
        return i.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      }).toList();

      final result = await api.signup(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        location: _selectedRegion,
        interests: interests,
        deviceName: deviceName,
        deviceOS: deviceOS,
      );

      final token =
          result['sessionToken'] as String? ?? result['token'] as String? ?? '';

      if (token.isNotEmpty && mounted) {
        await context.read<AuthProvider>().loginSuccess(token);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().darkMode;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF888888) : Colors.grey;
    final borderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _goBack,
                  child: Text('← Back',
                      style: TextStyle(color: subColor, fontSize: 14)),
                ),
                const SizedBox(height: 24),
                if (_step == 1)
                  _buildStep1(isDark, textColor, subColor, borderColor),
                if (_step == 2)
                  _buildStep2(isDark, textColor, subColor),
                if (_step == 3)
                  _buildStep3(isDark, textColor, subColor, borderColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(
      bool isDark, Color textColor, Color subColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create account',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 8),
        Text('Join PolyArticle today',
            style: TextStyle(fontSize: 15, color: subColor)),
        const SizedBox(height: 32),
        if (_error != null) _ErrorBox(_error!),
        _AuthField(
          controller: _emailController,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          action: TextInputAction.next,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
          onChanged: (_) => _clearError(),
        ),
        const SizedBox(height: 14),
        _AuthField(
          controller: _passwordController,
          hint: 'Password (min 8 chars)',
          obscure: !_showPassword,
          action: TextInputAction.next,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
          onChanged: (_) => _clearError(),
          suffix: GestureDetector(
            onTap: () => setState(() => _showPassword = !_showPassword),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(_showPassword ? '👁️' : '🙈',
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _AuthField(
          controller: _confirmController,
          hint: 'Confirm password',
          obscure: !_showConfirm,
          action: TextInputAction.done,
          textColor: textColor,
          subColor: subColor,
          borderColor: borderColor,
          onChanged: (_) => _clearError(),
          onSubmitted: (_) => _goStep2(),
          suffix: GestureDetector(
            onTap: () => setState(() => _showConfirm = !_showConfirm),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(_showConfirm ? '👁️' : '🙈',
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(label: 'Next', isDark: isDark, onTap: _goStep2),
      ],
    );
  }

  Widget _buildStep2(bool isDark, Color textColor, Color subColor) {
    final chipBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final chipBorder =
        isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD);
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedText = isDark ? Colors.black : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your interests',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 8),
        Text('Select topics you care about',
            style: TextStyle(fontSize: 15, color: subColor)),
        const SizedBox(height: 32),
        if (_error != null) _ErrorBox(_error!),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _interests.map((interest) {
            final selected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () {
                setState(() {
                  _error = null;
                  if (selected) {
                    _selectedInterests.remove(interest);
                  } else {
                    _selectedInterests.add(interest);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? selectedBg : chipBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: selected ? selectedBg : chipBorder),
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
        _PrimaryButton(label: 'Next', isDark: isDark, onTap: _goStep3),
      ],
    );
  }

  Widget _buildStep3(
      bool isDark, Color textColor, Color subColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your region',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 8),
        Text('Select your location for regional news',
            style: TextStyle(fontSize: 15, color: subColor)),
        const SizedBox(height: 32),
        if (_error != null) _ErrorBox(_error!),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRegion,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              style: TextStyle(color: textColor, fontSize: 15),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRegion = val);
              },
              items: _regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _handleSignup,
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
                : const Text('Create Account',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message,
          style: const TextStyle(color: Colors.red, fontSize: 14)),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final TextInputAction action;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color textColor;
  final Color subColor;
  final Color borderColor;

  const _AuthField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.action = TextInputAction.next,
    this.obscure = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      autocorrect: false,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: subColor),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: textColor.withOpacity(0.4)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffix,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PrimaryButton(
      {required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
