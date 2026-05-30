import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

import '../models/article.dart';
import '../providers/settings_provider.dart';

const _fallbackImage =
    'https://images.unsplash.com/photo-1504711434969-e33886168f5c';

class SwipeCard extends StatefulWidget {
  final Article item;
  final void Function(double strength) onLike;
  final void Function(double strength) onDislike;
  final void Function() onSave;
  final void Function() onOpenDetail;
  final void Function()? onSwipeDown;
  final bool disabled;

  const SwipeCard({
    super.key,
    required this.item,
    required this.onLike,
    required this.onDislike,
    required this.onSave,
    required this.onOpenDetail,
    this.onSwipeDown,
    this.disabled = false,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  double _totalDy = 0;
  bool _mounted = true;

  late AnimationController _controller;
  late Animation<Offset> _animation;

  NativeAd? _nativeAd;
  bool _adLoaded = false;
  bool _adFailed = false;
  bool _adRetried = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _animation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_controller);

    if (widget.item.type == 'ad') _loadAd();
  }

  void _loadAd() {
    final id = Platform.isAndroid
        ? dotenv.env['EXPO_PUBLIC_ADMOB_NATIVE_ID'] ?? ''
        : dotenv.env['EXPO_PUBLIC_ADMOB_IOS_NATIVE_ID'] ?? '';

    if (id.isEmpty) {
      if (_mounted) setState(() => _adFailed = true);
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: id,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (_mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, __) {
          ad.dispose();
          _nativeAd = null;
          if (_mounted && !_adRetried) {
            _adRetried = true;
            Future.delayed(const Duration(seconds: 30), () {
              if (_mounted && !_adLoaded) _loadAd();
            });
          } else if (_mounted) {
            setState(() => _adFailed = true);
          }
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.black,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF111111),
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF555555),
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF999999),
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 11.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _mounted = false;
    _controller.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (widget.disabled) return;
    _totalDy += d.delta.dy;
    setState(() {
      _drag = Offset(_drag.dx + d.delta.dx, 0);
    });
  }

  void _onPanEnd(DragEndDetails d, double width) async {
    if (widget.disabled) return;

    final settings = context.read<SettingsProvider>();
    final vx = d.velocity.pixelsPerSecond.dx;
    final vy = d.velocity.pixelsPerSecond.dy;
    final threshold = width * 0.35;

    // Swipe down to refresh
    if (vy > 400 && _totalDy > 50 && _drag.dx.abs() < 60) {
      _totalDy = 0;
      setState(() => _drag = Offset.zero);
      if (settings.haptics) HapticFeedback.lightImpact();
      widget.onSwipeDown?.call();
      return;
    }
    _totalDy = 0;

    if (_drag.dx > threshold || vx > 1100) {
      await _exit(Offset(width * 1.4, 120));
      _haptic(settings, true);
      widget.onLike(vx > 1100 ? 1.0 : 0.7);
    } else if (_drag.dx < -threshold || vx < -1100) {
      await _exit(Offset(-width * 1.4, 120));
      _haptic(settings, true);
      widget.onDislike(vx.abs() > 1100 ? 1.0 : 0.7);
    } else {
      _spring();
    }
  }

  void _haptic(SettingsProvider settings, bool strong) {
    if (!settings.haptics) return;
    if (strong) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _exit(Offset target) async {
    _totalDy = 0;
    _animation = Tween(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.reset();
    _animation.addListener(() {
      if (_mounted) setState(() => _drag = _animation.value);
    });
    await _controller.forward();
  }

  void _spring() {
    _animation = Tween(begin: _drag, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.duration = const Duration(milliseconds: 400);
    _controller.reset();
    _animation.addListener(() {
      if (_mounted) setState(() => _drag = _animation.value);
    });
    _controller.forward().then((_) {
      _controller.duration = const Duration(milliseconds: 220);
    });
  }

  double _rotation(double width) {
    final dx = _drag.dx.clamp(-width, width);
    return (dx / width) * 15 * (math.pi / 180);
  }

  double _likeOpacity(double width) =>
      (_drag.dx / (width * 0.35)).clamp(0.0, 1.0);

  double _nopeOpacity(double width) =>
      (-_drag.dx / (width * 0.35)).clamp(0.0, 1.0);

  Future<void> _share() async {
    try {
      final summary = widget.item.summary.isNotEmpty
          ? '\n\n${widget.item.summary}'
          : '';
      await Share.share(
        '${widget.item.title}$summary\n\nRead more: ${widget.item.url}\n\nvia PolyArticle',
        subject: widget.item.title,
      );
    } catch (_) {}
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.item.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.darkMode;

    return LayoutBuilder(builder: (context, constraints) {
      // Use the actual card width, not the full screen width.
      // SwipeDeck constrains us to a fixed SizedBox so this is always accurate.
      final width = constraints.maxWidth;
      final likeOp = _likeOpacity(width);
      final nopeOp = _nopeOpacity(width);

      return GestureDetector(
        onPanUpdate: widget.disabled ? null : _onPanUpdate,
        onPanEnd: widget.disabled ? null : (d) => _onPanEnd(d, width),
        child: Transform.translate(
          offset: _drag,
          child: Transform.rotate(
            angle: _rotation(width),
            child: Stack(
              children: [
                _cardBody(isDark),
                if (likeOp > 0)
                  Positioned(
                    top: 60,
                    right: 30,
                    child: Opacity(
                      opacity: likeOp,
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF22C55E)),
                      ),
                    ),
                  ),
                if (nopeOp > 0)
                  Positioned(
                    top: 60,
                    left: 30,
                    child: Opacity(
                      opacity: nopeOp,
                      child: const Text(
                        'NOPE',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _cardBody(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.item.type == 'ad' ? _adBody(isDark) : _articleBody(isDark),
    );
  }

  Widget _adBody(bool isDark) {
    final shimmer = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shimmerLight = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0);
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    if (_adLoaded && _nativeAd != null) {
      return Stack(
        children: [
          SizedBox.expand(child: AdWidget(ad: _nativeAd!)),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Sponsored',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_adFailed) {
      return Container(
        color: bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined,
                  size: 44, color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: 10),
              Text(
                'No ad available',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Skeleton loading state
    return Container(
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 12,
            width: 70,
            decoration: BoxDecoration(
              color: shimmerLight,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 16,
            width: double.infinity * 0.7,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: shimmerLight,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _articleBody(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final summaryColor =
        isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555);
    final metaColor =
        isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    final catColor =
        isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777);
    final circleBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final circleIconColor = isDark ? Colors.white : Colors.black;

    // Scale fonts by the shorter screen dimension so text stays proportional
    // on both narrow phones and wide tablets without going too small or large.
    final mq = MediaQuery.of(context).size;
    final scale = ((mq.shortestSide) / 390).clamp(0.88, 1.15);
    final titleSize = 20.0 * scale;
    final summarySize = 13.5 * scale;
    final metaSize = 11.5 * scale;
    final catSize = 11.5 * scale;

    return Column(
      children: [
        // IMAGE — top 52%
        Expanded(
          flex: 52,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.item.image ?? _fallbackImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => Container(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE8E8E8),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE8E8E8),
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.grey, size: 40),
                ),
              ),
              if (!widget.disabled)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _share,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // CONTENT — middle 33%
        Expanded(
          flex: 33,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.item.category != null)
                  Text(
                    widget.item.category!.toUpperCase(),
                    style: TextStyle(
                      fontSize: catSize,
                      fontWeight: FontWeight.w700,
                      color: catColor,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  widget.item.title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (widget.item.source.isNotEmpty)
                  Text(
                    widget.item.source,
                    style: TextStyle(fontSize: metaSize, color: metaColor),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    widget.item.summary,
                    style: TextStyle(
                      fontSize: summarySize,
                      color: summaryColor,
                      height: 1.35,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.onOpenDetail,
                    child: const Text(
                      '...Read More',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // BUTTONS — bottom 15% (always inside card)
        Expanded(
          flex: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Circle(
                bg: circleBg,
                iconColor: circleIconColor,
                onTap: widget.disabled ? null : () => widget.onDislike(0.7),
                child: Icon(Icons.close, size: 24, color: circleIconColor),
              ),
              const SizedBox(width: 28),
              _Circle(
                bg: circleBg,
                iconColor: circleIconColor,
                onTap: widget.disabled ? null : widget.onSave,
                child: Icon(Icons.bookmark_border,
                    size: 22, color: circleIconColor),
              ),
              const SizedBox(width: 28),
              _Circle(
                bg: circleBg,
                iconColor: circleIconColor,
                onTap: widget.disabled ? null : () => widget.onLike(0.7),
                child: Icon(Icons.check, size: 26, color: circleIconColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final Widget child;
  final Color bg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _Circle(
      {required this.child,
      required this.bg,
      required this.iconColor,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
