import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../providers/settings_provider.dart';

class ArticleScreen extends StatelessWidget {
  final Article article;
  final VoidCallback onBack;

  const ArticleScreen({
    super.key,
    required this.article,
    required this.onBack,
  });

  String _formatTime(String? publishedAt) {
    if (publishedAt == null) return '';
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(date);
    } catch (_) {
      return '';
    }
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(article.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _handleShare() async {
    try {
      await Share.share('${article.title}\n${article.url}',
          subject: article.title);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.darkMode;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Icon(Icons.arrow_back, color: textColor),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _handleShare,
                    child: Icon(Icons.share, color: textColor),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: article.image != null
                            ? CachedNetworkImage(
                                imageUrl: article.image!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFE0E0E0),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFE0E0E0),
                                  child: const Icon(Icons.image_not_supported,
                                      color: Colors.grey),
                                ),
                              )
                            : Container(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE0E0E0),
                                child: const Icon(Icons.article,
                                    color: Colors.grey, size: 48),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Category + source + time
                    Row(
                      children: [
                        if (article.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              article.category!,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            [
                              if (article.source.isNotEmpty) article.source,
                              if (_formatTime(article.publishedAt).isNotEmpty)
                                _formatTime(article.publishedAt),
                            ].join(' · '),
                            style:
                                TextStyle(color: subColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Title
                    Text(
                      article.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Summary
                    Text(
                      article.summary,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Read full article button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _openOriginal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.white : Colors.black,
                          foregroundColor:
                              isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Read Full Article',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
