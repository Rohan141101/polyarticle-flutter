import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/article.dart';
import '../providers/settings_provider.dart';
import '../services/api.dart' as api;
import '../services/event_logger.dart';
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
const _interstitialRepeatEvery = 6;
const _interstitialCooldownSecs = 90;

class FeedScreen extends StatefulWidget {
  final VoidCallback onProfilePress;
  final void Function(Article article) onOpenArticle;

  const FeedScreen({
    super.key,
    required this.onProfilePress,
    required this.onOpenArticle,
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

  int _swipeCount = 0;
  DateTime? _lastInterstitialTime;
  bool _interstitialLoaded = false;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  DateTime? _dwellStart;
  String? _currentArticleId;

  @override
  void initState() {
    super.initState();
    _loadInitialArticles();
    _loadBannerAd();
    _loadInterstitialAd();
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
          _interstitialAd = ad;
          _interstitialLoaded = true;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoaded = false;
        },
      ),
    );
  }

  void _maybeShowInterstitial() {
    final now = DateTime.now();

    final pastCooldown = _lastInterstitialTime == null ||
        now.difference(_lastInterstitialTime!).inSeconds >=
            _interstitialCooldownSecs;

    final shouldShow = _swipeCount >= _interstitialFirstThreshold &&
        (_swipeCount - _interstitialFirstThreshold) %
                _interstitialRepeatEvery ==
            0 &&
        pastCooldown;

    if (shouldShow && _interstitialLoaded && _interstitialAd != null) {
      _lastInterstitialTime = now;
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

      if (mounted) {
        setState(() => _items = _insertAds(articles));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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

      if (mounted && more.isNotEmpty) {
        setState(() {
          _page = nextPage;
          _items = [..._items, ..._insertAds(more)];
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

                const SizedBox(height: 10),

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
                                          alignment: const Alignment(0, -0.6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                            child: SizedBox(
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.68,
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
                                                onOpenDetail:
                                                    widget.onOpenArticle,
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
