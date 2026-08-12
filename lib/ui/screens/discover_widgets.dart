part of 'discover_screen.dart';

// Compact StoryCard fix: never use Column inside 86x120 constraints.
// Full file restored from local artifacts with overflow-safe cover-only tiles.

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

    // Compact carousel tiles: cover only (matches Inkitt). Fixed 120 height.
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
