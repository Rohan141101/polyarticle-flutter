import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api.dart' as api;
import '../services/event_logger.dart';
import '../services/session_storage.dart';
import '../widgets/swipe_deck.dart';

const _categories = [
  'For You',
  'Regional',
  'World',
  'Politics',
  'Business',
  'Stocks',
  'Crypto',
  'Sports',
  'Entertainment',
  'Technology',
  'Health',
  'General',
];

const _nativeAdInterval = 6;
const _interstitialFirstThreshold = 10;
const _maxInterstitialsPerDay = 2;
const _interstitialMinGapMinutes = 240;

class FeedScreen extends StatefulWidget {
  final VoidCallback onProfilePress;
  final void Function(Article article) onOpenArticle;
  final VoidCallback? onLogin;
  final VoidCallback? onSignup;

  const FeedScreen({
    super.key,
    required this.onProfilePress,
    required this.onOpenArticle,
    this.onLogin,
    this.onSignup,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _activeCategory = _categories.first;
  List<Article> _items = [];
  int _currentIndex = 0;
  int _page = 1;

  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _error;

  final Set<String> _seenIds = {};

  int _swipeCount = 0;
  int _interstitialShownToday = 0;
  String _interstitialShownDate = '';
  DateTime? _lastInterstitialTime;
  bool _interstitialLoaded = false;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  DateTime? _dwellStart;
  String? _currentArticleId;

  bool get _isGuest {
    final auth = context.read<AuthProvider>();
    final guest = context.read<GuestProvider>();
    return Platform.isIOS && guest.isGuest && !auth.isAuthenticated;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialArticles();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadInterstitialDayCount();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  String get _bannerAdUnitId => Platform.isAndroid
      ? dotenv.env['EXPO_PUBLIC_ADMOB_BANNER_ID'] ?? ''
      : dotenv.env['EXPO_PUBLIC_ADMOB_IOS_BANNER_ID'] ?? '';

  String get _interstitialAdUnitId => Platform.isAndroid
      ? dotenv.env['EXPO_PUBLIC_ADMOB_INTERSTITIAL_ID'] ?? ''
      : dotenv.env['EXPO_PUBLIC_ADMOB_IOS_INTERSTITIAL_ID'] ?? '';

  void _loadBannerAd() {
    if (_bannerAdUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    if (_interstitialAdUnitId.isEmpty) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialLoaded = false;
              _loadInterstitialAd();
            },
          );
          _interstitialAd = ad;
          _interstitialLoaded = true;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoaded = false;
          Future.delayed(const Duration(seconds: 60), () {
            if (mounted) _loadInterstitialAd();
          });
        },
      ),
    );
  }

  String _todayString() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _loadInterstitialDayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    if (prefs.getString('interstitial_date') == today) {
      _interstitialShownToday = prefs.getInt('interstitial_count') ?? 0;
      final lastMs = prefs.getInt('interstitial_last_ms');
      if (lastMs != null) {
        _lastInterstitialTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
    }
    _interstitialShownDate = today;
  }

  Future<void> _saveInterstitialCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('interstitial_date', _interstitialShownDate);
    await prefs.setInt('interstitial_count', _interstitialShownToday);
    if (_lastInterstitialTime != null) {
      await prefs.setInt(
          'interstitial_last_ms', _lastInterstitialTime!.millisecondsSinceEpoch);
    }
  }

  void _maybeShowInterstitial() {
    if (_swipeCount < _interstitialFirstThreshold) return;

    final today = _todayString();
    if (_interstitialShownDate != today) {
      _interstitialShownToday = 0;
      _interstitialShownDate = today;
      _lastInterstitialTime = null;
    }

    if (_interstitialShownToday >= _maxInterstitialsPerDay) return;

    final now = DateTime.now();
    if (_lastInterstitialTime != null &&
        now.difference(_lastInterstitialTime!).inMinutes <
            _interstitialMinGapMinutes) return;

    if (_interstitialLoaded && _interstitialAd != null) {
      _lastInterstitialTime = now;
      _interstitialShownToday++;
      _saveInterstitialCount();
      _interstitialAd!.show();
      _interstitialAd = null;
      _interstitialLoaded = false;
      _loadInterstitialAd();
    }
  }

  List<Article> _insertAds(List<Article> articles) {
    final result = <Article>[];

    for (int i = 0; i < articles.length; i++) {
      result.add(articles[i]);

      if ((i + 1) % _nativeAdInterval == 0) {
        result.add(Article(
          id: 'ad_${_activeCategory}_${_page}_$i',
          title: '',
          summary: '',
          url: '',
          source: '',
          type: 'ad',
        ));
      }
    }

    return result;
  }

  Future<void> _loadInitialArticles({bool fresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _currentIndex = 0;
      _page = 1;
      _seenIds.clear();
    });

    try {
      List<Article> articles;

      if (_activeCategory == 'Regional') {
        articles = await api.fetchRegionalNews(limit: 20);
      } else {
        articles = await api.fetchNews(
          _activeCategory,
          page: 1,
          limit: 20,
          fresh: fresh,
        );
      }

      final unique = articles.where((a) => _seenIds.add(a.id)).toList();
      if (mounted) {
        setState(() => _items = _insertAds(unique));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg == 'UNAUTHORIZED' && _isGuest) {
          // Guest token expired — regenerate silently and retry
          try {
            final guest = context.read<GuestProvider>();
            final token = await api.createGuestSession(
              interests: guest.cleanInterests,
              region: guest.region,
            );
            await saveSession(token);
            _loadInitialArticles(fresh: fresh);
            return;
          } catch (_) {}
        }
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_loadingMore || _activeCategory == 'Regional') return;

    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;

      final more = await api.fetchNews(
        _activeCategory,
        page: nextPage,
        limit: 20,
      );

      final unique = more.where((a) => _seenIds.add(a.id)).toList();
      if (mounted && unique.isNotEmpty) {
        setState(() {
          _page = nextPage;
          _items = [..._items, ..._insertAds(unique)];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onSwipeDown() async {
    setState(() => _refreshing = true);
    await _loadInitialArticles(fresh: true);
    if (mounted) setState(() => _refreshing = false);
  }

  void _onCategoryChange(String category) {
    if (category == _activeCategory) return;

    setState(() => _activeCategory = category);
    _loadInitialArticles();
  }

  void _onIndexChange(int newIndex) {
    if (_currentArticleId != null && _dwellStart != null) {
      final dwell = DateTime.now().difference(_dwellStart!).inMilliseconds;
      eventLogger.log('impression', _currentArticleId!,
          extra: {'dwellMs': dwell});
    }

    setState(() => _currentIndex = newIndex);

    if (newIndex < _items.length) {
      final currentItem = _items[newIndex];
      if (currentItem.type == 'article') {
        _currentArticleId = currentItem.id;
        _dwellStart = DateTime.now();
      }
    }

    if (newIndex >= _items.length - 5) {
      _loadMoreArticles();
    }
  }

  void _onSwipe(String direction, double strength) {
    _swipeCount++;

    final currentItem =
        _currentIndex < _items.length ? _items[_currentIndex] : null;

    if (currentItem != null && currentItem.type == 'article') {
      eventLogger.log(direction, currentItem.id);
      if (direction == 'save' && !_isGuest) {
        api.addBookmark(currentItem.id).catchError((_) {});
      }
    }

    final settings = context.read<SettingsProvider>();

    if (settings.haptics) {
      if (strength > 0.8) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }

    _maybeShowInterstitial();
  }

  Widget _buildGuestPrompt(Color textColor, Color subColor, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 56, color: isDark ? Colors.white54 : Colors.black26),
            const SizedBox(height: 20),
            Text(
              'Create a free account',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign up to access your personalised news feed.',
              style: TextStyle(fontSize: 14, color: subColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.onSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Sign Up',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onLogin,
              child: Text(
                'Already have an account? Log In',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.darkMode;

    final bg = isDark ? Colors.black : const Color(0xFFF7F7F7);
    final text = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PolyArticle',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: text,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onProfilePress,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[300],
                          child: Icon(Icons.person,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // CATEGORY PILLS
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final isActive = cat == _activeCategory;

                      return GestureDetector(
                        onTap: () => _onCategoryChange(cat),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 90),
                          margin: const EdgeInsets.only(right: 10),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                    ? const Color(0xFF222222)
                                    : const Color(0xFFEAEAEA)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? (isDark ? Colors.black : Colors.white)
                                  : (isDark
                                      ? const Color(0xFFAAAAAA)
                                      : const Color(0xFF555555)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 3),

                // SWIPE AREA
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: text))
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_error!,
                                      style:
                                          const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadInitialArticles,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _items.isEmpty
                              ? Center(
                                  child: Text('No articles found',
                                      style: TextStyle(color: subColor)))
                              : _currentIndex >= _items.length
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text("You're all caught up!",
                                              style:
                                                  TextStyle(color: subColor)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _loadInitialArticles(
                                                    fresh: true),
                                            child: const Text('Refresh'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _refreshing
                                      ? Center(
                                          child: CircularProgressIndicator(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Align(
                                          alignment: const Alignment(0, -0.50),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: ConstrainedBox(
                                              // Cap width on tablets; phones use full width.
                                              constraints: const BoxConstraints(maxWidth: 420),
                                              child: SwipeDeck(
                                                    data: _items,
                                                    currentIndex: _currentIndex,
                                                    onIndexChange: _onIndexChange,
                                                    onLike: (s) =>
                                                        _onSwipe('swipe_right', s),
                                                    onDislike: (s) =>
                                                        _onSwipe('swipe_left', s),
                                                    onSave: () =>
                                                        _onSwipe('save', 1.0),
                                                    onOpenDetail: (article) {
                                                      eventLogger.log('open_detail', article.id);
                                                      widget.onOpenArticle(article);
                                                    },
                                                    onSwipeDown: _onSwipeDown,
                                                  ),
                                                ),
                                              ),
                                          ),
                ),
              ],
            ),

            // REFRESH SPINNER — drops from top to just below pills
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              top: _refreshing ? 110 : -48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),

            // STICKY BANNER
            if (_isBannerLoaded && _bannerAd != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: isDark ? Colors.black : Colors.white,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
