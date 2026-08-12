import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

import 'explore_screen.dart';
import 'reader_screen.dart';
import 'story_detail_screen.dart';

part 'discover_widgets.dart';
part 'discover_search.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.data,
    required this.apiService,
  });

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<String> _tabs;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = widget.data.discoverTabs.isNotEmpty
        ? widget.data.discoverTabs
        : const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _CategoryTabs(
                labels: _tabs,
                tabController: _tabController,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildTabContent(_selectedTabIndex)),
      ],
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tabLabel = _tabs[tabIndex].toLowerCase();
    final allBooks = _booksForDiscover();
    final sections = _discoverSectionsForTab(tabLabel, allBooks);
    final showExploreLead = tabLabel == 'new' && sections.isNotEmpty;

    return Container(
      color: Colors.white,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          if (showExploreLead) ...[
            _ExploreStoriesSection(
              books: sections.first.books,
              topics: widget.data.exploreTopics,
              apiService: widget.apiService,
              onOpenExplore: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      topics: widget.data.exploreTopics,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          for (var i = 0; i < sections.length; i++) ...[
            if (!(showExploreLead && i == 0)) ...[
              _DynamicStoryRail(
                section: sections[i],
                apiService: widget.apiService,
              ),
              const SizedBox(height: 24),
              if (i == 1) ...[
                _GenrePillRow(
                  topics: widget.data.exploreTopics,
                  books: allBooks,
                  apiService: widget.apiService,
                  onOpenExplore: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExploreScreen(
                          topics: widget.data.exploreTopics,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              if (i == 2) ...[
                _AuthorsStrip(books: allBooks, apiService: widget.apiService),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ],
      ),
    );
  }

  List<BookCardModel> _booksForDiscover() {
    if (widget.data.discoverBooks.isNotEmpty) {
      return widget.data.discoverBooks;
    }
    final seen = <int>{};
    final merged = <BookCardModel>[];
    for (final book in [
      ...widget.data.recentlyUpdated,
      ...widget.data.recentlyCompleted,
    ]) {
      if (!seen.contains(book.id)) {
        seen.add(book.id);
        merged.add(book);
      }
    }
    return merged;
  }

  List<_DiscoverRailSection> _discoverSectionsForTab(
    String tab,
    List<BookCardModel> books,
  ) {
    List<BookCardModel> takeWhere(bool Function(BookCardModel) test) {
      return books.where(test).toList();
    }

    final recentlyUpdated = takeWhere((b) => b.sectionName == 'recently_updated');
    final recentlyCompleted = takeWhere(
      (b) => b.sectionName == 'recently_completed' || b.isCompleted,
    );
    final topRated = [...books]..sort((a, b) => b.rating.compareTo(a.rating));
    final fantasy = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('fantasy') ||
          b.secondaryGenre.toLowerCase().contains('fantasy'),
    );
    final paranormal = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('urban'),
    );
    final action = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('action') ||
          b.secondaryGenre.toLowerCase().contains('action') ||
          b.primaryGenre.toLowerCase().contains('adventure') ||
          b.secondaryGenre.toLowerCase().contains('adventure'),
    );

    switch (tab) {
      case 'popular':
        return [
          _DiscoverRailSection(title: 'Trending Now', books: topRated.take(10).toList()),
          _DiscoverRailSection(title: 'Most Completed', books: recentlyCompleted.take(10).toList()),
          _DiscoverRailSection(title: 'Fan Favorites', books: topRated.skip(2).take(10).toList()),
        ];
      case 'fanfiction':
        return [
          _DiscoverRailSection(title: 'Fan Picks', books: topRated.take(10).toList()),
          _DiscoverRailSection(
            title: 'Romance & Drama',
            books: takeWhere(
              (b) =>
                  b.primaryGenre.toLowerCase().contains('romance') ||
                  b.primaryGenre.toLowerCase().contains('drama'),
            ).take(10).toList(),
          ),
          _DiscoverRailSection(title: 'Completed Fan Stories', books: recentlyCompleted.take(10).toList()),
        ];
      case 'newsfeed':
        return [
          _DiscoverRailSection(title: 'Fresh Updates', books: recentlyUpdated.take(10).toList()),
          _DiscoverRailSection(title: 'Staff Picks', books: topRated.take(10).toList()),
          _DiscoverRailSection(title: 'Rising Stories', books: topRated.skip(4).take(10).toList()),
        ];
      default:
        return [
          _DiscoverRailSection(title: 'Recently Updated', books: recentlyUpdated.take(12).toList()),
          _DiscoverRailSection(title: 'Recently Completed', books: recentlyCompleted.take(12).toList()),
          _DiscoverRailSection(title: 'Selected Stories', books: topRated.take(12).toList()),
          _DiscoverRailSection(title: 'New in Fantasy', books: fantasy.take(12).toList()),
          _DiscoverRailSection(title: 'Action & Adventure Fantasy', books: action.take(12).toList()),
          _DiscoverRailSection(title: 'Paranormal & Urban Fantasy', books: paranormal.take(12).toList()),
        ];
    }
  }
}
