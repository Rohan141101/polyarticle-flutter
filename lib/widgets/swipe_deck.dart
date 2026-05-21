import 'package:flutter/material.dart';
import '../models/article.dart';
import 'swipe_card.dart';

class SwipeDeck extends StatefulWidget {
  final List<Article> data;
  final int currentIndex;
  final void Function(int newIndex) onIndexChange;
  final void Function(double strength)? onLike;
  final void Function(double strength)? onDislike;
  final void Function()? onSave;
  final void Function(Article article)? onOpenDetail;
  final void Function()? onSwipeDown;

  const SwipeDeck({
    super.key,
    required this.data,
    required this.currentIndex,
    required this.onIndexChange,
    this.onLike,
    this.onDislike,
    this.onSave,
    this.onOpenDetail,
    this.onSwipeDown,
  });

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> {
  bool _isTransitioning = false;

  void _handleNext() {
    if (_isTransitioning) return;
    _isTransitioning = true;
    final nextIndex = widget.currentIndex + 1;
    widget.onIndexChange(nextIndex);

    final prefetchIndex = nextIndex + 1;
    if (prefetchIndex < widget.data.length) {
      final img = widget.data[prefetchIndex].image;
      if (img != null && mounted) {
        precacheImage(NetworkImage(img), context);
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _isTransitioning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final idx = widget.currentIndex;

    if (data.isEmpty || idx >= data.length) return const SizedBox.shrink();

    final safeBack1 = idx + 1 < data.length ? idx + 1 : null;
    final safeBack2 = idx + 2 < data.length ? idx + 2 : null;

    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth;
      // Fixed aspect ratio (w:h ≈ 1:1.55). Also cap by available height so
      // the card never overflows on short phones (e.g. iPhone SE).
      final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 680.0;
      final cardHeight = (cardWidth * 1.55).clamp(300.0, maxH.clamp(300.0, 680.0));

      return SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (safeBack2 != null)
              _buildBackCard(data[safeBack2], scale: 0.90, yOffset: 14),
            if (safeBack1 != null)
              _buildBackCard(data[safeBack1], scale: 0.95, yOffset: 7),
            SwipeCard(
              key: ValueKey('card_$idx'),
              item: data[idx],
              disabled: false,
              onSwipeDown: widget.onSwipeDown,
              onLike: (strength) {
                widget.onLike?.call(strength);
                _handleNext();
              },
              onDislike: (strength) {
                widget.onDislike?.call(strength);
                _handleNext();
              },
              onSave: () {
                widget.onSave?.call();
                _handleNext();
              },
              onOpenDetail: () {
                widget.onOpenDetail?.call(data[idx]);
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBackCard(Article item, {required double scale, double yOffset = 0}) {
    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: SwipeCard(
          key: ValueKey('back_${item.id}'),
          item: item,
          disabled: true,
          onLike: (_) {},
          onDislike: (_) {},
          onSave: () {},
          onOpenDetail: () {},
        ),
      ),
    );
  }
}
