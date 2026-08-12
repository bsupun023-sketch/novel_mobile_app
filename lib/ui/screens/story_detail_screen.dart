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
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _loadingChapters = true;
  List<Map<String, dynamic>> _chapters = const [];
  List<String> _tags = const [];
  List<Map<String, dynamic>> _reviews = const [];
  bool _loadingReviews = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tags = List<String>.from(widget.book.tags);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingChapters = true;
      _loadingReviews = true;
      _error = null;
    });
    try {
      final detail = await widget.apiService.fetchPublicBook(_book.id);
      if (detail != null && mounted) {
        setState(() {
          _book = BookDetailModel.fromMap(detail);
          _tags = List<String>.from(_book.tags);
        });
      }
      final chapters = await widget.apiService.fetchStoryChapters(_book.id);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
      final aid = _book.authorUserId;
      if (aid != null) {
        final following = await widget.apiService.fetchAuthorFollowing(aid);
        if (mounted) setState(() => _isFollowing = following);
      }
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingChapters = false;
          _loadingReviews = false;
          _error = 'Unable to load story details.';
        });
      }
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
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _openReadingListPicker() async {
    try {
      var lists = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      final choice = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Save to reading list',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new list'),
                  onTap: () =>
                      Navigator.pop(ctx, <String, dynamic>{'_create': true}),
                ),
                if (lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No lists yet — create one above.'),
                  ),
                ...lists.map((list) {
                  final name = list['name'] as String? ?? 'List';
                  return ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(name),
                    onTap: () => Navigator.pop(ctx, list),
                  );
                }),
              ],
            ),
          );
        },
      );
      if (choice == null) return;

      if (choice['_create'] == true) {
        final nameCtrl = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Create reading list'),
            content: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'List name'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, nameCtrl.text.trim()),
                child: const Text('Create'),
              ),
            ],
          ),
        );
        if (name == null || name.isEmpty) return;
        final created = await widget.apiService.createReadingList({
          'name': name,
          'story_count': 0,
          'cover_path': '',
          'sort_order': lists.length + 1,
        });
        var newId = (created['id'] as num?)?.toInt() ?? 0;
        if (newId == 0) {
          lists = await widget.apiService.fetchReadingLists();
          for (final l in lists) {
            if ((l['name'] as String?) == name) {
              newId = (l['id'] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }
        if (newId != 0) {
          await widget.apiService.addReadingListItem(newId, _book.id);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newId != 0
                ? 'Created "$name" and saved this story'
                : 'Created "$name". Open Library to confirm.'),
          ),
        );
        return;
      }

      final listId = (choice['id'] as num?)?.toInt() ?? 0;
      if (listId == 0) return;
      await widget.apiService.addReadingListItem(listId, _book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Saved to ${choice['name'] ?? 'reading list'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401') || e.toString().contains('403')
                ? 'Please sign in to use reading lists'
                : 'Could not save to reading list',
          ),
        ),
      );
    }
  }

  void _openChapter(Map<String, dynamic> chapter) {
    final chapterTitle = chapter['title'] as String? ?? 'Untitled chapter';
    final chapterNumber = chapter['chapter_number'] as int? ?? 1;
    final chapterContent = chapter['content'] as String? ?? '';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          apiService: widget.apiService,
          title: _book.title,
          author: _book.author,
          coverPath: _book.coverPath,
          chapterNumber: chapterNumber,
          chapterTitle: chapterTitle,
          chapterContent: chapterContent,
          bookId: _book.id,
          tags: _tags,
          authorUserId: _book.authorUserId,
        ),
      ),
    );
  }

  void _readNow() {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters available yet')),
      );
      return;
    }
    _openChapter(_chapters.first);
  }

  Future<void> _openTag(String tag) async {
    final books = await widget.apiService.fetchBooksByTag(tag);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TagBooksScreen(
          tag: tag,
          books: books,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = _book.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(_book.coverPath);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            title: Text(
              _book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  final action = await showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                    items: const [
                      PopupMenuItem(
                          value: 'list', child: Text('Save to reading list')),
                      PopupMenuItem(
                          value: 'review', child: Text('Write a review')),
                    ],
                  );
                  if (action == 'list') {
                    await _openReadingListPicker();
                  } else if (action == 'review') {
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _WriteReviewScreen(
                          bookId: _book.id,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                    final reviews =
                        await widget.apiService.fetchBookReviews(_book.id);
                    if (mounted) setState(() => _reviews = reviews);
                  }
                },
              ),
            ],
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: coverUrl == null
                        ? Container(
                            width: 110,
                            height: 160,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.menu_book, size: 40),
                          )
                        : Image.network(
                            coverUrl,
                            width: 110,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 110,
                              height: 160,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _book.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('by ${_book.author}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54)),
                        const SizedBox(height: 10),
                        if (_book.rating > 0)
                          Row(children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(_book.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ]),
                        if (_book.statusText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_book.statusText,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                        ],
                        const SizedBox(height: 12),
                        if (_book.authorUserId != null)
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed:
                                  _loadingFollow ? null : _toggleFollow,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _isFollowing
                                      ? Colors.grey.shade400
                                      : const Color(0xFFE85D4C),
                                ),
                                foregroundColor: _isFollowing
                                    ? Colors.black54
                                    : const Color(0xFFE85D4C),
                              ),
                              child:
                                  Text(_isFollowing ? 'Following' : 'Follow'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    _book.description.isEmpty
                        ? 'No summary available.'
                        : _book.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          if (_tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tags',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags
                          .map(
                            (t) => ActionChip(
                              label: Text(t.startsWith('#') ? t : '#$t'),
                              onPressed: () => _openTag(t),
                              backgroundColor: const Color(0xFFFFF0EE),
                              labelStyle: const TextStyle(
                                color: Color(0xFFE85D4C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text('Reviews',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _WriteReviewScreen(
                            bookId: _book.id,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                      final reviews =
                          await widget.apiService.fetchBookReviews(_book.id);
                      if (mounted) setState(() => _reviews = reviews);
                    },
                    child: const Text('Write'),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingReviews)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            )
          else if (_reviews.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('No reviews yet. Be the first to review.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final r = _reviews[index];
                  final rating = (r['rating'] as num?)?.toInt() ?? 0;
                  final comment = r['comment'] as String? ??
                      r['body'] as String? ??
                      '';
                  final author = r['display_name'] as String? ??
                      r['author'] as String? ??
                      'Reader';
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    title: Row(
                      children: [
                        Text(author,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ...List.generate(
                          rating.clamp(0, 5),
                          (_) => const Icon(Icons.star,
                              size: 14, color: Colors.amber),
                        ),
                      ],
                    ),
                    subtitle: comment.isEmpty ? null : Text(comment),
                  );
                },
                childCount: _reviews.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Chapters',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_loadingChapters)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_chapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No chapters published yet.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = _chapters[index];
                  final title =
                      chapter['title'] as String? ?? 'Untitled chapter';
                  final number =
                      chapter['chapter_number'] as int? ?? index + 1;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    title: Text('Chapter $number',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openChapter(chapter),
                  );
                },
                childCount: _chapters.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
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
                backgroundColor: const Color(0xFFE85D4C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Read Now',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagBooksScreen extends StatelessWidget {
  const _TagBooksScreen({
    required this.tag,
    required this.books,
    required this.apiService,
  });

  final String tag;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tag.startsWith('#') ? tag : '#$tag')),
      body: books.isEmpty
          ? const Center(child: Text('No stories with this tag yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = books[index];
                final title = b['title'] as String? ?? 'Untitled';
                final author = b['author'] as String? ?? '';
                final cover = b['cover_path'] as String? ?? '';
                return ListTile(
                  leading: cover.isEmpty
                      ? const Icon(Icons.menu_book)
                      : Image.network(
                          apiService.resolveAssetUrl(cover),
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ),
                  title: Text(title),
                  subtitle: Text(author),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel.fromMap(b),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _WriteReviewScreen extends StatefulWidget {
  const _WriteReviewScreen({
    required this.bookId,
    required this.apiService,
  });

  final int bookId;
  final ApiService apiService;

  @override
  State<_WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<_WriteReviewScreen> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.createBookReview(widget.bookId, {
        'rating': _rating,
        'comment': _controller.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Share your thoughts…',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D4C),
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
