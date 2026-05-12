import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/article.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/active_sessions_screen.dart';
import 'screens/article_screen.dart';

enum _UnauthScreen { login, signup, forgot }

enum _AuthScreen { feed, profile, sessions, article }

class PolyArticleApp extends StatelessWidget {
  const PolyArticleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
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
  _UnauthScreen _unauthScreen = _UnauthScreen.login;
  _AuthScreen _authScreen = _AuthScreen.feed;
  Article? _selectedArticle;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    // Wait for settings + auth to finish loading
    if (!settings.loaded || auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      return _buildUnauthFlow();
    }
    return _buildAuthFlow();
  }

  Widget _buildUnauthFlow() {
    switch (_unauthScreen) {
      case _UnauthScreen.login:
        return LoginScreen(
          onSignup: () => setState(() => _unauthScreen = _UnauthScreen.signup),
          onForgot: () => setState(() => _unauthScreen = _UnauthScreen.forgot),
        );
      case _UnauthScreen.signup:
        return SignupScreen(
          onBack: () => setState(() => _unauthScreen = _UnauthScreen.login),
        );
      case _UnauthScreen.forgot:
        return ForgotPasswordScreen(
          onBack: () => setState(() => _unauthScreen = _UnauthScreen.login),
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
        );
      case _AuthScreen.profile:
        return ProfileScreen(
          onBack: () => setState(() => _authScreen = _AuthScreen.feed),
          onActiveSessions: () =>
              setState(() => _authScreen = _AuthScreen.sessions),
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
          );
        }
        return ArticleScreen(
          article: _selectedArticle!,
          onBack: () => setState(() => _authScreen = _AuthScreen.feed),
        );
    }
  }
}
