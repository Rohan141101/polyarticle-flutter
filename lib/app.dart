import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/article.dart';
import 'providers/auth_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/guest_interests_screen.dart';
import 'screens/guest_region_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/active_sessions_screen.dart';
import 'screens/article_screen.dart';

enum _UnauthScreen { welcome, login, signup, forgot }
enum _GuestScreen { interests, region }
enum _AuthScreen { feed, profile, sessions, article }

class PolyArticleApp extends StatelessWidget {
  const PolyArticleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GuestProvider()..load()),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'PolyArticle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Colors.black),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: Colors.white),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  _UnauthScreen _unauthScreen = _UnauthScreen.welcome;
  _GuestScreen _guestScreen = _GuestScreen.interests;
  _AuthScreen _authScreen = _AuthScreen.feed;
  Article? _selectedArticle;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guest = context.watch<GuestProvider>();
    final settings = context.watch<SettingsProvider>();

    if (!settings.loaded || auth.loading || !guest.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Authenticated user → full app
    if (auth.isAuthenticated) return _buildAuthFlow();

    // iOS guest → go straight to feed (shows articles or signup prompt)
    if (Platform.isIOS && guest.isGuest) {
      return _buildAuthFlow();
    }

    // Unauth flow
    return _buildUnauthFlow();
  }

  Widget _buildUnauthFlow() {
    switch (_unauthScreen) {
      case _UnauthScreen.welcome:
        if (Platform.isIOS) {
          return WelcomeScreen(
            onLogin: () =>
                setState(() => _unauthScreen = _UnauthScreen.login),
            onSignup: () =>
                setState(() => _unauthScreen = _UnauthScreen.signup),
            onContinueAsGuest: () =>
                setState(() => _guestScreen = _GuestScreen.interests),
          );
        }
        return _buildLoginScreen();
      case _UnauthScreen.login:
        return _buildLoginScreen();
      case _UnauthScreen.signup:
        return SignupScreen(
          onBack: () => setState(() => _unauthScreen =
              Platform.isIOS ? _UnauthScreen.welcome : _UnauthScreen.login),
        );
      case _UnauthScreen.forgot:
        return ForgotPasswordScreen(
          onBack: () => setState(() => _unauthScreen = _UnauthScreen.login),
        );
    }
  }

  Widget _buildLoginScreen() {
    return LoginScreen(
      onSignup: () => setState(() => _unauthScreen = _UnauthScreen.signup),
      onForgot: () => setState(() => _unauthScreen = _UnauthScreen.forgot),
    );
  }

  Widget _buildGuestOnboarding() {
    switch (_guestScreen) {
      case _GuestScreen.interests:
        return GuestInterestsScreen(
          onNext: () =>
              setState(() => _guestScreen = _GuestScreen.region),
          onBack: () {
            context.read<GuestProvider>().clearGuest();
            setState(() => _unauthScreen = _UnauthScreen.welcome);
          },
        );
      case _GuestScreen.region:
        return GuestRegionScreen(
          onDone: () => setState(() {}),
          onBack: () =>
              setState(() => _guestScreen = _GuestScreen.interests),
        );
    }
  }

  Widget _buildAuthFlow() {
    switch (_authScreen) {
      case _AuthScreen.feed:
        return FeedScreen(
          onProfilePress: () =>
              setState(() => _authScreen = _AuthScreen.profile),
          onOpenArticle: (article) {
            setState(() {
              _selectedArticle = article;
              _authScreen = _AuthScreen.article;
            });
          },
          onLogin: () {
            context.read<GuestProvider>().clearGuest();
            setState(() => _unauthScreen = _UnauthScreen.login);
          },
          onSignup: () {
            context.read<GuestProvider>().clearGuest();
            setState(() => _unauthScreen = _UnauthScreen.signup);
          },
        );
      case _AuthScreen.profile:
        return ProfileScreen(
          onBack: () => setState(() => _authScreen = _AuthScreen.feed),
          onActiveSessions: () =>
              setState(() => _authScreen = _AuthScreen.sessions),
          onLogin: () {
            context.read<GuestProvider>().clearGuest();
            setState(() {
              _authScreen = _AuthScreen.feed;
              _unauthScreen = _UnauthScreen.login;
            });
          },
          onSignup: () {
            context.read<GuestProvider>().clearGuest();
            setState(() {
              _authScreen = _AuthScreen.feed;
              _unauthScreen = _UnauthScreen.signup;
            });
          },
        );
      case _AuthScreen.sessions:
        return ActiveSessionsScreen(
          onBack: () => setState(() => _authScreen = _AuthScreen.profile),
        );
      case _AuthScreen.article:
        if (_selectedArticle == null) {
          return FeedScreen(
            onProfilePress: () =>
                setState(() => _authScreen = _AuthScreen.profile),
            onOpenArticle: (article) {
              setState(() {
                _selectedArticle = article;
                _authScreen = _AuthScreen.article;
              });
            },
            onLogin: () {
              context.read<GuestProvider>().clearGuest();
              setState(() => _unauthScreen = _UnauthScreen.login);
            },
            onSignup: () {
              context.read<GuestProvider>().clearGuest();
              setState(() => _unauthScreen = _UnauthScreen.signup);
            },
          );
        }
        return ArticleScreen(
          article: _selectedArticle!,
          onBack: () => setState(() => _authScreen = _AuthScreen.feed),
        );
    }
  }
}
