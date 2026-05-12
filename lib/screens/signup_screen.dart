import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../services/api.dart' as api;
import '../providers/auth_provider.dart';

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

  // Step 1
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  // Step 2
  final Set<String> _selectedInterests = {};

  // Step 3
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

  void _goStep2() {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
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

      final token = result['sessionToken'] as String? ??
          result['token'] as String? ??
          '';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: _step == 1 ? widget.onBack : () => setState(() {
                  _error = null;
                  _step -= 1;
                }),
                child: const Text(
                  '← Back',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create account',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join PolyArticle today',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        if (_error != null) _buildError(),
        _buildTextField(
          controller: _emailController,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _passwordController,
          hint: 'Password (min 8 chars)',
          obscure: !_showPassword,
          action: TextInputAction.next,
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
        _buildTextField(
          controller: _confirmController,
          hint: 'Confirm password',
          obscure: !_showConfirm,
          action: TextInputAction.done,
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
        _buildPrimaryButton('Next', _goStep2),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your interests',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select topics you care about',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        if (_error != null) _buildError(),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _interests.map((interest) {
            final selected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () {
                setState(() {
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
                  color: selected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? Colors.black : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Text(
                  interest,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton('Next', _goStep3),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your region',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your location for regional news',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        if (_error != null) _buildError(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRegion,
              isExpanded: true,
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
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
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

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(_error!,
          style: const TextStyle(color: Colors.red, fontSize: 14)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      autocorrect: false,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
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
