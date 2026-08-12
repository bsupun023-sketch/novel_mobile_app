part of 'discover_screen.dart';

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text, this.onReadMore});
  final String text;
  final VoidCallback? onReadMore;
  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim().isEmpty ? 'No description available yet.' : widget.text.trim();
    final needsToggle = text.length > 180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded || !needsToggle ? null : 4,
          overflow: _expanded || !needsToggle ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: const Color(0xFF555555)),
        ),
        if (needsToggle)
          TextButton(
            onPressed: () {
              if (widget.onReadMore != null) {
                widget.onReadMore!();
                return;
              }
              setState(() => _expanded = !_expanded);
            },
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(_expanded ? 'Show less' : 'Read more', style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  if (normalized.length < 6) return const Color(0xFFA1A1A1);
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ExploreStoriesSection extends StatelessWidget {
  const _ExploreStoriesSection({required this.books, required this.topics, required this.apiService, required this.onOpenExplore});
  final List<BookCardModel> books;
  final List<ExploreTopicModel> topics;
  final ApiService apiService;
  final VoidCallback onOpenExplore;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final lead = books.first;
    final covers = books.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lead.primaryGenre.isEmpty ? 'Portal Fantasy' : lead.primaryGenre, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: covers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = covers[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => StoryDetailScreen(
                      apiService: apiService,
                      book: BookDetailModel(
                        id: item.id, title: item.title, author: item.author,
                        description: item.description, statusText: item.statusText,
                        rating: item.rating, genre: item.primaryGenre, cta: item.cta,
                        coverPath: item.coverPath, authorUserId: item.authorUserId,
                      ),
                    ),
                  ));
                },
                child: _StoryCard(book: item, width: 86, apiService: apiService),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(book: lead, apiService: apiService),
        const SizedBox(height: 16),
        _GenrePillRow(topics: topics, books: books, apiService: apiService, onOpenExplore: onOpenExplore),
      ],
    );
  }
}

class _DiscoverRailSection {
  const _DiscoverRailSection({required this.title, required this.books});
  final String title;
  final List<BookCardModel> books;
}

class _DynamicStoryRail extends StatefulWidget {
  const _DynamicStoryRail({required this.section, required this.apiService});
  final _DiscoverRailSection section;
  final ApiService apiService;
  @override
  State<_DynamicStoryRail> createState() => _DynamicStoryRailState();
}

class _DynamicStoryRailState extends State<_DynamicStoryRail> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.32);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.books.isEmpty) return const SizedBox.shrink();
    final book = widget.section.books[_activeIndex.clamp(0, widget.section.books.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.section.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _pageController,
            padEnds: true,
            itemCount: widget.section.books.length,
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              final item = widget.section.books[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10, left: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => StoryDetailScreen(
                        apiService: widget.apiService,
                        book: BookDetailModel(
                          id: item.id, title: item.title, author: item.author,
                          description: item.description, statusText: item.statusText,
                          rating: item.rating, genre: item.primaryGenre, cta: item.cta,
                          coverPath: item.coverPath, authorUserId: item.authorUserId,
                        ),
                      ),
                    ));
                  },
                  child: _StoryCard(book: item, width: 96, apiService: widget.apiService),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(
          book: book,
          apiService: widget.apiService,
          onRead: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => StoryDetailScreen(
                apiService: widget.apiService,
                book: BookDetailModel(
                  id: book.id, title: book.title, author: book.author,
                  description: book.description, statusText: book.statusText,
                  rating: book.rating, genre: book.primaryGenre, cta: book.cta,
                  coverPath: book.coverPath, authorUserId: book.authorUserId,
                ),
              ),
            ));
          },
        ),
      ],
    );
  }
}

class _ActiveStoryDetail extends StatelessWidget {
  const _ActiveStoryDetail({required this.book, this.onRead, this.apiService});
  final BookCardModel book;
  final VoidCallback? onRead;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _ExpandableDescription(
          text: book.description,
          onReadMore: () {
            if (onRead != null) { onRead!(); return; }
            if (apiService == null) return;
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => StoryDetailScreen(
                apiService: apiService!,
                book: BookDetailModel(
                  id: book.id, title: book.title, author: book.author,
                  description: book.description, statusText: book.statusText,
                  rating: book.rating, genre: book.primaryGenre, cta: book.cta,
                  coverPath: book.coverPath, authorUserId: book.authorUserId,
                ),
              ),
            ));
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.muted),
              const SizedBox(width: 4),
              Text(book.statusText.isEmpty ? 'Updated recently' : book.statusText, style: Theme.of(context).textTheme.bodySmall),
            ]),
            if (book.rating > 0)
              Row(mainAxisSize: MainAxisSize.min, children: List.generate(
                book.rating.round().clamp(0, 5),
                (_) => const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3C623))),
              )),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (book.isCompleted) ...[
              const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.brand),
              Text('Completed', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.brand)),
            ],
            _GenreTag(label: book.primaryGenre.isEmpty ? 'Novel' : book.primaryGenre),
            if (book.secondaryGenre.isNotEmpty) _GenreTag(label: book.secondaryGenre),
            ElevatedButton(
              onPressed: onRead,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brand, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), minimumSize: const Size(0, 36)),
              child: Text(book.cta, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
    );
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({required this.book, required this.apiService, this.width = 140});
  final BookCardModel book;
  final ApiService apiService;
  final double width;
  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  bool _isFollowing = false;
  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final authorId = widget.book.authorUserId;
    if (authorId == null) return;
    final following = await widget.apiService.fetchAuthorFollowing(authorId);
    if (!mounted) return;
    setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    final authorId = widget.book.authorUserId;
    if (authorId == null) return;
    try {
      if (_isFollowing) {
        await widget.apiService.unfollowAuthor(authorId);
        setState(() => _isFollowing = false);
      } else {
        await widget.apiService.followAuthor(authorId);
        setState(() => _isFollowing = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.book.accentHex);
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: widget.width <= 86 ? 0.5 : 0.62,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: widget.book.coverPath.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(widget.apiService.resolveAssetUrl(widget.book.coverPath)),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: widget.book.coverPath.isEmpty
                        ? Container(color: color.withValues(alpha: 0.3), child: const Icon(Icons.menu_book))
                        : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('by ${widget.book.author}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.book.authorUserId != null)
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isFollowing ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(color: _isFollowing ? AppTheme.brand : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorsStrip extends StatefulWidget {
  const _AuthorsStrip({required this.books, required this.apiService});
  final List<BookCardModel> books;
  final ApiService apiService;
  @override
  State<_AuthorsStrip> createState() => _AuthorsStripState();
}

class _AuthorsStripState extends State<_AuthorsStrip> {
  Map<int, bool> _following = {};
  @override
  void initState() {
    super.initState();
    _loadFollowStates();
  }

  Future<void> _loadFollowStates() async {
    final ids = <int>[];
    final seenNames = <String>{};
    for (final book in widget.books) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      if (seenNames.contains(name)) continue;
      seenNames.add(name);
      final aid = book.authorUserId;
      if (aid != null) ids.add(aid);
      if (seenNames.length >= 8) break;
    }
    if (ids.isEmpty) return;
    final map = await widget.apiService.fetchAuthorsFollowing(ids);
    if (!mounted) return;
    setState(() => _following = map);
  }

  Future<void> _toggleFollowFor(int authorId) async {
    final currently = _following[authorId] ?? false;
    try {
      if (currently) {
        await widget.apiService.unfollowAuthor(authorId);
      } else {
        await widget.apiService.followAuthor(authorId);
      }
      if (!mounted) return;
      setState(() => _following[authorId] = !currently);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final byAuthor = <String, BookCardModel>{};
    for (final book in widget.books) {
      byAuthor.putIfAbsent(book.author.trim().isEmpty ? 'Unknown' : book.author, () => book);
      if (byAuthor.length >= 8) break;
    }
    final authors = byAuthor.entries.toList();
    if (authors.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New Authors on Inkitt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: authors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = authors[index].key;
              final book = authors[index].value;
              final letter = author.isNotEmpty ? author[0].toUpperCase() : 'A';
              final authorId = book.authorUserId;
              final isFollowing = authorId != null ? (_following[authorId] ?? false) : false;
              return Column(
                children: [
                  GestureDetector(
                    onTap: authorId != null ? () => _toggleFollowFor(authorId) : null,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE8EEF9),
                      child: Text(letter, style: const TextStyle(color: AppTheme.brand)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    child: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({required this.topics, required this.books, required this.apiService, this.onOpenExplore});
  final List<ExploreTopicModel> topics;
  final List<BookCardModel> books;
  final ApiService apiService;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final genres = <String>{};
    for (final b in books) {
      if (b.primaryGenre.isNotEmpty) genres.add(b.primaryGenre);
      if (genres.length >= 8) break;
    }
    final items = genres.toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ActionChip(label: Text(items[index]), onPressed: onOpenExplore);
        },
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.labels, required this.tabController});
  final List<String> labels;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final isSelected = tabController.index == index;
          return GestureDetector(
            onTap: () => tabController.animateTo(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(labels[index], style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected ? AppTheme.brand : AppTheme.muted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  width: isSelected ? math.max(labels[index].length * 11.0, 60) : 0,
                  color: isSelected ? AppTheme.brand : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarDelegate({required this.child});
  @override
  double get maxExtent => 64;
  @override
  double get minExtent => 64;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
