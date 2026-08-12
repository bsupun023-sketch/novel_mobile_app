import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.entries,
    required this.apiService,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<LibraryEntryModel> _entries;
  List<ReadingListModel> _readingLists = [];
  bool _listsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _entries = List<LibraryEntryModel>.from(widget.entries);
    _loadLists();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _entries = List<LibraryEntryModel>.from(widget.entries);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isCompleted(LibraryEntryModel e) =>
      e.readingStatus.toLowerCase().contains('complete');

  Future<void> _loadLists() async {
    setState(() => _listsLoading = true);
    try {
      final rows = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      setState(() {
        _readingLists = rows.map(ReadingListModel.fromMap).toList();
        _listsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _listsLoading = false);
    }
  }

  Future<void> _createList() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New List'),
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
      final created = await widget.apiService.createReadingList({
        'name': name,
        'story_count': 0,
        'cover_path': '',
        'sort_order': _readingLists.length + 1,
      });
      await _loadLists();
      if (!mounted) return;
      final newId = (created['id'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newId != null
                ? 'Created "$name"'
                : 'Created "$name". Pull to refresh if it is not visible.',
          ),
        ),
      );
      if (_readingLists.isEmpty ||
          !_readingLists.any((l) => l.name == name)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _loadLists();
      }
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
      });
      setState(() {
        final i = _entries.indexWhere((x) => x.id == e.id);
        if (i >= 0) {
          _entries[i] = LibraryEntryModel(
            id: e.id,
            book: e.book,
            readingStatus: next,
            updatedText: e.updatedText,
            chapters: e.chapters,
            primaryGenre: e.primaryGenre,
            secondaryGenre: e.secondaryGenre,
          );
        }
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = _entries.where((e) => !_isCompleted(e)).toList();
    final completed = _entries.where(_isCompleted).toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverAppBar(
            pinned: true,
            title: const Text('Library'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Reading'),
                Tab(text: 'Lists'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createList,
                tooltip: 'Create list',
              ),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              onRefresh: () async {
                // parent may reload bootstrap; keep local toggle state
              },
              child: reading.isEmpty && completed.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No library entries yet')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (reading.isNotEmpty) ...[
                          Text('Currently reading',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ...reading.map(
                            (e) => Card(
                              child: ListTile(
                                title: Text(e.book.title),
                                subtitle: Text(e.readingStatus),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: () => _toggle(e),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (completed.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Completed',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ...completed.map(
                            (e) => Card(
                              child: ListTile(
                                title: Text(e.book.title),
                                subtitle: Text(e.readingStatus),
                                trailing: IconButton(
                                  icon: const Icon(Icons.undo),
                                  onPressed: () => _toggle(e),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            RefreshIndicator(
              onRefresh: _loadLists,
              child: _listsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _readingLists.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            const Center(child: Text('No reading lists yet')),
                            const SizedBox(height: 12),
                            Center(
                              child: FilledButton(
                                onPressed: _createList,
                                child: const Text('Create list'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _readingLists.length,
                          itemBuilder: (context, index) {
                            final list = _readingLists[index];
                            return Card(
                              child: ListTile(
                                title: Text(list.name),
                                subtitle: Text('${list.storyCount} stories'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openList(list),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
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
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.fetchReadingListDetail(widget.listId);
      final items = List<Map<String, dynamic>>.from(
        data['items'] as List<dynamic>? ?? [],
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete list?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (ok != true) return;
              await widget.api.deleteReadingList(widget.listId);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No stories in this list'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final title = item['title'] as String? ??
                        item['book_title'] as String? ??
                        'Story';
                    final itemId = (item['id'] as num?)?.toInt();
                    return ListTile(
                      title: Text(title),
                      trailing: itemId == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () async {
                                await widget.api.removeReadingListItem(
                                  widget.listId,
                                  itemId,
                                );
                                await _load();
                              },
                            ),
                    );
                  },
                ),
    );
  }
}
