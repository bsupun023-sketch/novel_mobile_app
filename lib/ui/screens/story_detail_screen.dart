import 'package:flutter/material.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'chapter_reader_screen.dart';

class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({
    super.key,
    required this.book,
    required this.apiService,
  });

  final BookDetailModel book;
  final ApiService apiService;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late BookDetailModel _book;
  bool _loading = true;
  List<Map<String, dynamic>> _chapters = const [];
  List<String> _tags = const [];
  int _likesCount = 0;
  bool _isFollowing = false;
  bool _loadingFollow = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tags = List<String>.from(widget.book.tags);
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.apiService.fetchPublicBook(_book.id);
      if (detail != null && mounted) {
        setState(() {
          _book = BookDetailModel.fromMap(detail);
          _tags = List<String>.from(_book.tags);
          _likesCount = (detail['likes_count'] as num?)?.toInt() ?? 0;
        });
      }
      final chapters = await widget.apiService.fetchStoryChapters(_book.id);
      if (mounted) setState(() { _chapters = chapters; _loading = false; });
      final aid = _book.authorUserId;
      if (aid != null) {
        try {
          final f = await widget.apiService.fetchAuthorFollowing(aid);
          if (mounted) setState(() => _isFollowing = f);
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final aid = _book.authorUserId;
    if (aid == null || _loadingFollow) return;
    setState(() => _loadingFollow = true);
    try {
      if (_isFollowing) {
        await widget.apiService.unfollowAuthor(aid);
      } else {
        await widget.apiService.followAuthor(aid);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to follow')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  void _readNow() {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters yet')),
      );
      return;
    }
    final ch = _chapters.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          bookId: _book.id,
          chapterNumber: (ch['chapter_number'] as num?)?.toInt() ?? 1,
          chapterTitle: ch['title'] as String? ?? 'Chapter 1',
          chapterContent: ch['content'] as String? ?? '',
          apiService: widget.apiService,
          bookTitle: _book.title,
          chapters: _chapters,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _book.coverPath.isNotEmpty
        ? widget.apiService.resolveAssetUrl(_book.coverPath)
        : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              await showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                items: const [
                  PopupMenuItem(value: 'list', child: Text('Save to reading list')),
                ],
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: coverUrl == null
                        ? Container(
                            width: 160,
                            height: 230,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.menu_book, size: 48),
                          )
                        : Image.network(
                            coverUrl,
                            width: 160,
                            height: 230,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 160,
                              height: 230,
                              color: Colors.grey.shade300,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_florist, size: 18, color: Color(0xFFE85D4C)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _book.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_book.author.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'by ${_book.author}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('Chapters', '${_chapters.length}'),
                    _stat(
                      'Story Status',
                      _book.statusText.isNotEmpty ? _book.statusText : '—',
                    ),
                    _stat('Reviews', '${_likesCount > 0 ? "★" : ""}'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _book.description.isEmpty ? 'No summary yet.' : _book.description,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.favorite_border),
                      label: Text(_likesCount > 0 ? '$_likesCount Likes' : 'Likes'),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.star_border),
                      label: const Text('Reviews'),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map(
                          (t) => Chip(
                            label: Text('#$t'),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        _book.author.isNotEmpty
                            ? _book.author[0].toUpperCase()
                            : 'A',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _book.author.isEmpty ? 'Unknown author' : _book.author,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_book.authorUserId != null)
                      OutlinedButton(
                        onPressed: _loadingFollow ? null : _toggleFollow,
                        child: Text(_isFollowing ? 'Following' : 'Follow'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chapters',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_chapters.isEmpty)
                  const Text('No chapters published yet.')
                else
                  ...List.generate(_chapters.length, (i) {
                    final ch = _chapters[i];
                    final title = ch['title'] as String? ?? 'Untitled';
                    final num = (ch['chapter_number'] as num?)?.toInt() ?? i + 1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text('$num', style: TextStyle(color: Colors.grey.shade600)),
                      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChapterReaderScreen(
                              bookId: _book.id,
                              chapterNumber: num,
                              chapterTitle: title,
                              chapterContent: ch['content'] as String? ?? '',
                              apiService: widget.apiService,
                              bookTitle: _book.title,
                              chapters: _chapters,
                              initialIndex: i,
                            ),
                          ),
                        );
                      },
                    );
                  }),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _readNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Read Now',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
