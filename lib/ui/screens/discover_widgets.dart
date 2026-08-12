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
    final text = widget.text.trim().isEmpty
        ? 'No description available yet.'
        : widget.text.trim();
    final needsToggle = text.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded || !needsToggle ? null : 4,
          overflow: _expanded || !needsToggle
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: const Color(0xFF555555),
          ),
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
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
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
  const _ExploreStoriesSection({
    required this.books,
    required this.apiService,
    this.onReadMore,
  });

  final List<BookCardModel> books;
  final ApiService apiService;
  final void Function(BookCardModel book)? onReadMore;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const SizedBox.shrink();
    }
    final book = books.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Stories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 86,
                height: 120,
                child: _StoryCard(
                  book: book,
                  apiService: apiService,
                  width: 86,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${book.author}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _ExpandableDescription(
                      text: book.description,
                      onReadMore: onReadMore == null
                          ? null
                          : () => onReadMore!(book),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GenrePillRow(
            genres: books
                .map((b) => b.primaryGenre)
                .where((g) => g.trim().isNotEmpty)
                .toSet()
                .take(8)
                .toList(),
          ),
        ],
      ),
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
  @override
  Widget build(BuildContext context) {
    final books = widget.section.books;
    if (books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            widget.section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _StoryCard(
                book: books[index],
                apiService: widget.apiService,
                width: 86,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.book,
    required this.apiService,
    this.width = 140,
  });

  final BookCardModel book;
  final ApiService apiService;
  final double width;

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: widget.book.id,
            title: widget.book.title,
            author: widget.book.author,
            description: widget.book.description,
            statusText: widget.book.statusText,
            rating: widget.book.rating,
            genre: widget.book.primaryGenre,
            cta: widget.book.cta,
            coverPath: widget.book.coverPath,
            authorUserId: widget.book.authorUserId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.book.accentHex);
    final coverUrl = widget.book.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(widget.book.coverPath);
    final compact = widget.width <= 100;

    // Compact carousel tiles: cover only. Parent is often 86x120 — never use Column.
    if (compact) {
      return GestureDetector(
        onTap: _openDetail,
        child: SizedBox(
          width: widget.width,
          height: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl == null
                ? ColoredBox(
                    color: color.withValues(alpha: 0.15),
                    child: const Center(child: Icon(Icons.menu_book, size: 28)),
                  )
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    width: widget.width,
                    height: 120,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: color.withValues(alpha: 0.15),
                      child: const Center(child: Icon(Icons.menu_book, size: 28)),
                    ),
                  ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: coverUrl == null
                    ? Container(
                        color: color.withValues(alpha: 0.2),
                        child: const Center(child: Icon(Icons.menu_book)),
                      )
                    : Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withValues(alpha: 0.2),
                          child: const Center(child: Icon(Icons.menu_book)),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${widget.book.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                ],
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
  @override
  Widget build(BuildContext context) {
    final authors = <String, BookCardModel>{};
    for (final b in widget.books) {
      if (b.author.trim().isEmpty) continue;
      authors.putIfAbsent(b.author, () => b);
    }
    final list = authors.values.take(12).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'New Authors on Inkitt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final book = list[index];
              return SizedBox(
                width: 72,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        book.author.isNotEmpty ? book.author[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              genres[index],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
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
    return TabBar(
      controller: tabController,
      isScrollable: true,
      labelColor: Colors.black87,
      unselectedLabelColor: Colors.black45,
      indicatorColor: const Color(0xFF00C853),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      tabs: labels.map((l) => Tab(text: l)).toList(),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 1 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
