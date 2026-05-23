import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/api.dart' as api;
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onForgot;
  final VoidCallback? onBack;

  const LoginScreen({
    super.key,
    required this.onSignup,
    required this.onForgot,
    this.onBack,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text; // never trim — passwords can have leading/trailing spaces

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

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

      final result = await api.login(
        email: email,
        password: password,
        deviceName: deviceName,
        deviceOS: deviceOS,
      );

      final token =
          result['sessionToken'] as String? ?? result['token'] as String? ?? '';
      if (token.isNotEmpty && mounted) {
        await context.read<AuthProvider>().loginSuccess(token);
        await context.read<GuestProvider>().clearGuest();
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
      canPop: true,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onBack != null)
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Text('← Back',
                        style: TextStyle(color: subColor, fontSize: 14)),
                  ),
                if (widget.onBack != null) const SizedBox(height: 24),
                Text(
                  'Welcome back',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textColor),
                ),
                const SizedBox(height: 8),
                Text('Sign in to your account',
                    style: TextStyle(fontSize: 15, color: subColor)),
                const SizedBox(height: 36),
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
                  hint: 'Password',
                  obscure: !_showPassword,
                  action: TextInputAction.done,
                  textColor: textColor,
                  subColor: subColor,
                  borderColor: borderColor,
                  onChanged: (_) => _clearError(),
                  onSubmitted: (_) => _handleLogin(),
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _showPassword = !_showPassword),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(_showPassword ? '👁️' : '🙈',
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.onForgot,
                    child: Text('Forgot password?',
                        style: TextStyle(color: subColor, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleLogin,
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
                        : const Text('Log in',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: TextStyle(color: subColor)),
                    GestureDetector(
                      onTap: widget.onSignup,
                      child: Text('Sign up',
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
