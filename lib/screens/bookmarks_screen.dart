import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/settings_provider.dart';
import '../services/api.dart' as api;

class BookmarksScreen extends StatefulWidget {
  final VoidCallback onBack;

  const BookmarksScreen({super.key, required this.onBack});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Article> _bookmarks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await api.getBookmarks();
      if (mounted) setState(() => _bookmarks = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Article article) async {
    setState(() => _bookmarks.removeWhere((a) => a.id == article.id));
    try {
      await api.removeBookmark(article.id);
    } catch (_) {
      if (mounted) setState(() => _bookmarks.insert(0, article));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.darkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Icon(Icons.arrow_back, color: textColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Saved Articles',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: textColor))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _bookmarks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_border, size: 56,
                                      color: isDark ? Colors.white24 : Colors.black12),
                                  const SizedBox(height: 16),
                                  Text('No saved articles yet',
                                      style: TextStyle(color: subColor, fontSize: 15)),
                                  const SizedBox(height: 8),
                                  Text('Tap the bookmark icon on any article to save it',
                                      style: TextStyle(color: subColor, fontSize: 13),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _bookmarks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final article = _bookmarks[i];
                                  return Dismissible(
                                    key: ValueKey(article.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.delete_outline,
                                          color: Colors.white, size: 26),
                                    ),
                                    onDismissed: (_) => _remove(article),
                                    child: GestureDetector(
                                      onTap: () => _openUrl(article.url),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            if (article.image != null)
                                              ClipRRect(
                                                borderRadius: const BorderRadius.horizontal(
                                                    left: Radius.circular(12)),
                                                child: CachedNetworkImage(
                                                  imageUrl: article.image!,
                                                  width: 90,
                                                  height: 90,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    width: 90,
                                                    height: 90,
                                                    color: isDark
                                                        ? const Color(0xFF2A2A2A)
                                                        : const Color(0xFFE8E8E8),
                                                    child: const Icon(Icons.image_not_supported,
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (article.category != null)
                                                      Text(
                                                        article.category!.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: subColor,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      article.title,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: textColor,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      article.source,
                                                      style: TextStyle(
                                                          fontSize: 12, color: subColor),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(right: 12),
                                              child: Icon(Icons.open_in_new,
                                                  size: 16, color: subColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
