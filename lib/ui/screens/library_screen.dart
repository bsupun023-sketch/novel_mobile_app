import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Temporary working Library screen.
/// For the full private-list detail UI (add/remove stories), copy
/// artifacts/fixes/library_screen.dart over this file.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.onOpenDiscover,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final VoidCallback onOpenDiscover;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LibraryEntryModel> _entries = [];
  List<ReadingListModel> _lists = [];
  bool _loadingEntries = true;
  bool _loadingLists = true;

  bool _isCompleted(LibraryEntryModel e) =>
      e.readingStatus.toLowerCase().contains('complete');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _entries = List<LibraryEntryModel>.from(widget.data.libraryEntries);
    _lists = List<ReadingListModel>.from(widget.data.profile.readingLists);
    _loadingEntries = false;
    _loadingLists = false;
    _loadEntries();
    _loadLists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loadingEntries = true);
    try {
      final rows = await widget.apiService.fetchLibraryEntries();
      if (!mounted) return;
      setState(() {
        _entries = rows
            .map((m) => LibraryEntryModel.fromMap(m))
            .toList();
        _loadingEntries = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEntries = false);
    }
  }

  Future<void> _loadLists() async {
    setState(() => _loadingLists = true);
    try {
      final rows = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      setState(() {
        _lists = rows
            .map((m) => ReadingListModel.fromMap(m))
            .toList();
        _loadingLists = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<void> _createList() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New reading list'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.apiService.createReadingList({
        'name': name,
        'story_count': 0,
        'cover_path': '',
        'sort_order': _lists.length + 1,
      });
      await _loadLists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') || e.toString().contains('403')
                  ? 'Please sign in to create a reading list'
                  : 'Could not create list: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openList(ReadingListModel list) async {
    if (list.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pull to refresh lists first')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ListDetail(
          listId: list.id,
          listName: list.name,
          api: widget.apiService,
        ),
      ),
    );
    await _loadLists();
  }

  Future<void> _toggle(LibraryEntryModel e) async {
    final next = _isCompleted(e) ? 'Reading' : 'Completed';
    try {
      await widget.apiService.updateLibraryEntry(e.id, {
        'reading_status': next,
        'updated_text': e.updatedText,
        'chapters': e.chapters,
        'primary_genre': e.primaryGenre,
        'secondary_genre': e.secondaryGenre,
      });
      await _loadEntries();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  Future<void> _delete(LibraryEntryModel e) async {
    try {
      await widget.apiService.deleteLibraryEntry(e.id);
      await _loadEntries();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _entries.where((e) => !_isCompleted(e)).toList();
    final history = _entries.where(_isCompleted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Text(
            'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          tabs: const [
            Tab(text: 'Current'),
            Tab(text: 'History'),
            Tab(text: 'Lists'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EntriesPane(
                entries: current,
                loading: _loadingEntries,
                history: false,
                api: widget.apiService,
                onDiscover: widget.onOpenDiscover,
                onToggle: _toggle,
                onDelete: _delete,
                onRefresh: _loadEntries,
              ),
              _EntriesPane(
                entries: history,
                loading: _loadingEntries,
                history: true,
                api: widget.apiService,
                onDiscover: widget.onOpenDiscover,
                onToggle: _toggle,
                onDelete: _delete,
                onRefresh: _loadEntries,
              ),
              _ListsPane(
                lists: _lists,
                loading: _loadingLists,
                onCreate: _createList,
                onOpen: _openList,
                onRefresh: _loadLists,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntriesPane extends StatelessWidget {
  const _EntriesPane({
    required this.entries,
    required this.loading,
    required this.history,
    required this.api,
    required this.onDiscover,
    required this.onToggle,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<LibraryEntryModel> entries;
  final bool loading;
  final bool history;
  final ApiService api;
  final VoidCallback onDiscover;
  final ValueChanged<LibraryEntryModel> onToggle;
  final ValueChanged<LibraryEntryModel> onDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        children: [
          Text(
            history ? 'Reading History' : 'My Books',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (history) ...[
            const SizedBox(height: 8),
            Text(
              'Mark Completed from Current Reads to sync here.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 18),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (entries.isEmpty)
            Center(
              child: Text(
                history ? 'No completed books yet' : 'No books yet',
                style: const TextStyle(color: AppTheme.muted),
              ),
            )
          else
            ...entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoryDetailScreen(
                        apiService: api,
                        book: BookDetailModel(
                          id: e.book.id,
                          title: e.book.title,
                          author: e.book.author,
                          description: e.book.description,
                          statusText: e.book.statusText,
                          rating: e.book.rating,
                          genre: e.book.primaryGenre,
                          cta: e.book.cta,
                          coverPath: e.book.coverPath,
                          authorUserId: e.book.authorUserId,
                        ),
                      ),
                    ),
                  );
                },
                leading: SizedBox(
                  width: 48,
                  height: 64,
                  child: e.book.coverPath.isNotEmpty
                      ? Image.network(
                          api.resolveAssetUrl(e.book.coverPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFFE4E4E4)),
                        )
                      : const ColoredBox(color: Color(0xFFE4E4E4)),
                ),
                title: Text(
                  e.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${e.readingStatus} · ${e.primaryGenre}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'status') onToggle(e);
                    if (v == 'delete') onDelete(e);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        history ? 'Mark as Reading' : 'Mark as Completed',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          if (!history) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Discover more stories'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListsPane extends StatelessWidget {
  const _ListsPane({
    required this.lists,
    required this.loading,
    required this.onCreate,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<ReadingListModel> lists;
  final bool loading;
  final VoidCallback onCreate;
  final ValueChanged<ReadingListModel> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        children: [
          Row(
            children: [
              Text(
                'Reading Lists',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (lists.isEmpty)
            const Text('No lists yet. Create one to save stories.')
          else
            ...lists.map(
              (l) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.playlist_play),
                title: Text(l.name),
                subtitle: Text('${l.storyCount} stories'),
                onTap: () => onOpen(l),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListDetail extends StatefulWidget {
  const _ListDetail({
    required this.listId,
    required this.listName,
    required this.api,
  });

  final int listId;
  final String listName;
  final ApiService api;

  @override
  State<_ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<_ListDetail> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.api.fetchReadingListItems(widget.listId);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.listName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No stories in this list yet'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final b = _items[i];
                    final title = b['title'] as String? ?? 'Story';
                    final cover = b['cover_path'] as String? ?? '';
                    return ListTile(
                      leading: cover.isEmpty
                          ? const Icon(Icons.menu_book)
                          : Image.network(
                              widget.api.resolveAssetUrl(cover),
                              width: 40,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                      title: Text(title),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              apiService: widget.api,
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
