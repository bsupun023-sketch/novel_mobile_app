import 'package:flutter/material.dart';

import '../../data/services/api_service.dart';

class ChapterReaderScreen extends StatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.apiService,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.chapterContent,
    this.bookId,
    this.tags = const [],
    this.authorUserId,
  });

  final ApiService apiService;
  final String title;
  final String author;
  final String coverPath;
  final int chapterNumber;
  final String chapterTitle;
  final String chapterContent;
  final int? bookId;
  final List<String> tags;
  final int? authorUserId;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  bool _isFollowing = false;
  bool _loadingFollow = false;

  @override
  void initState() {
    super.initState();
    _loadFollow();
  }

  Future<void> _loadFollow() async {
    final aid = widget.authorUserId;
    if (aid == null) return;
    try {
      final following = await widget.apiService.fetchAuthorFollowing(aid);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final aid = widget.authorUserId;
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
          const SnackBar(content: Text('Could not update follow')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _saveToReadingList() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
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
                  title: Text(
                    'Save to reading list',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                child: const Text('Cancel'),
              ),
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
          await widget.apiService.addReadingListItem(newId, bookId);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newId != 0
                  ? 'Created "$name" and saved this story'
                  : 'Created "$name". Open Library to confirm.',
            ),
          ),
        );
        return;
      }

      final listId = (choice['id'] as num?)?.toInt() ?? 0;
      if (listId == 0) return;
      await widget.apiService.addReadingListItem(listId, bookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${choice['name'] ?? 'list'}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${widget.chapterNumber}'),
        actions: [
          if (widget.authorUserId != null)
            TextButton(
              onPressed: _loadingFollow ? null : _toggleFollow,
              child: Text(_isFollowing ? 'Following' : 'Follow'),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final action = await showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                items: const [
                  PopupMenuItem(
                    value: 'list',
                    child: Text('Save to reading list'),
                  ),
                ],
              );
              if (action == 'list') await _saveToReadingList();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.coverPath.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.apiService.resolveAssetUrl(widget.coverPath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          if (widget.coverPath.isNotEmpty) const SizedBox(height: 16),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'by ${widget.author}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
          if (widget.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.tags
                  .map(
                    (t) => Chip(
                      label: Text(t.startsWith('#') ? t : '#$t'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFFFF0EE),
                      labelStyle: const TextStyle(
                        color: Color(0xFFE85D4C),
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Chapter ${widget.chapterNumber}: ${widget.chapterTitle}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.chapterContent.isEmpty
                ? 'This chapter has not been written yet.'
                : widget.chapterContent,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
