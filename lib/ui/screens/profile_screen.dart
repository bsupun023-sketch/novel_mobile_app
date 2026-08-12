import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'edit_chapter_screen.dart';
import 'story_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.apiService,
    required this.achievements,
  });

  final ProfileModel profile;
  final ApiService apiService;
  final List<AchievementGroupModel> achievements;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _storiesFuture;
  late Future<List<Map<String, dynamic>>> _wallFuture;
  late Future<List<Map<String, dynamic>>> _activityFuture;
  Map<String, dynamic>? _userProfile;
  bool _isSavingProfile = false;
  bool _isFollowing = false;
  int? _followerCount;
  List<LibraryEntryModel> _currentReads = const [];
  List<Map<String, dynamic>> _myReviews = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _storiesFuture = widget.apiService.fetchWriterStories();
    _wallFuture = widget.apiService.fetchChatMessages();
    _activityFuture = widget.apiService.fetchNotifications();
    _loadUserProfile();
    _loadReadingAndReviews();
  }

  Future<void> _loadReadingAndReviews() async {
    try {
      final entries = await widget.apiService.fetchLibraryEntries();
      final reviews = await widget.apiService.fetchMyReviews();
      if (!mounted) return;
      final parsed = <LibraryEntryModel>[];
      for (final row in entries) {
        try {
          parsed.add(LibraryEntryModel.fromMap(row));
        } catch (_) {}
      }
      setState(() {
        _currentReads = parsed
            .where((e) {
              final s = e.readingStatus.toLowerCase().trim();
              return s != 'completed' &&
                  s != 'complete' &&
                  s != 'finished' &&
                  s != 'done';
            })
            .toList();
        _myReviews = reviews;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadUserProfile() async {
    final userProfile = await widget.apiService.fetchMe();
    if (!mounted) {
      return userProfile;
    }
    setState(() {
      _userProfile = userProfile;
    });
    // If viewing another user's profile, initialize follow state and follower count
    final viewingId = widget.profile.id;
    final currentUserId = (_userProfile?['id'] as int?);
    if (viewingId != null &&
        currentUserId != null &&
        viewingId != currentUserId) {
      // load the public profile for the user being viewed
      final otherProfile = await widget.apiService.fetchProfile(viewingId);
      final following = await widget.apiService.fetchAuthorFollowing(viewingId);
      if (mounted) {
        setState(() {
          _userProfile = otherProfile.isNotEmpty ? otherProfile : _userProfile;
          _isFollowing = following;
          _followerCount =
              (otherProfile['followers'] as int?) ?? widget.profile.followers;
        });
      }
    } else {
      // viewing self
      _followerCount = widget.profile.followers;
    }
    return userProfile;
  }

  String _valueAsString(Object? value) {
    return value?.toString() ?? '';
  }

  Future<void> _showEditProfileSheet() async {
    final currentProfile = _userProfile;
    if (currentProfile == null) {
      return;
    }

    final displayNameController = TextEditingController(
      text: _valueAsString(currentProfile['display_name']),
    );
    final bioController = TextEditingController(
      text: _valueAsString(currentProfile['bio']),
    );
    String photoUrl = _valueAsString(currentProfile['photo_url']);
    String coverUrl = _valueAsString(currentProfile['cover_url']);
    bool uploadingPhoto = false;
    bool uploadingCover = false;

    Future<void> pickImage(
      bool isCover,
      void Function(String) updateUrl,
      void Function(bool) updateUploading,
    ) async {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      updateUploading(true);
      try {
        final bytes = await picked.readAsBytes();
        final response = await widget.apiService.uploadUserImage(
          bytes,
          picked.name,
        );
        final uploadedPath = _valueAsString(response['path']);
        if (uploadedPath.isNotEmpty) {
          updateUrl(uploadedPath);
        }
      } finally {
        updateUploading(false);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit profile',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell readers about yourself…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Profile photo',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFE5E5E5),
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(
                                widget.apiService.resolveAssetUrl(photoUrl),
                              )
                            : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                displayNameController.text.isNotEmpty
                                    ? displayNameController.text
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : 'U',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: AppTheme.muted),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton(
                              onPressed: uploadingPhoto
                                  ? null
                                  : () async {
                                      await pickImage(
                                        false,
                                        (value) => setModalState(() {
                                          photoUrl = value;
                                        }),
                                        (value) => setModalState(() {
                                          uploadingPhoto = value;
                                        }),
                                      );
                                    },
                              child: Text(
                                uploadingPhoto
                                    ? 'Uploading…'
                                    : photoUrl.isEmpty
                                    ? 'Upload photo'
                                    : 'Change photo',
                              ),
                            ),
                            if (photoUrl.isNotEmpty)
                              TextButton(
                                onPressed: () => setModalState(() {
                                  photoUrl = '';
                                }),
                                child: const Text('Remove photo'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Cover image',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (coverUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.apiService.resolveAssetUrl(coverUrl),
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: uploadingCover
                              ? null
                              : () async {
                                  await pickImage(
                                    true,
                                    (value) => setModalState(() {
                                      coverUrl = value;
                                    }),
                                    (value) => setModalState(() {
                                      uploadingCover = value;
                                    }),
                                  );
                                },
                          child: Text(
                            uploadingCover
                                ? 'Uploading…'
                                : coverUrl.isEmpty
                                ? 'Upload cover'
                                : 'Change cover',
                          ),
                        ),
                      ),
                      if (coverUrl.isNotEmpty)
                        TextButton(
                          onPressed: () => setModalState(() {
                            coverUrl = '';
                          }),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingProfile
                          ? null
                          : () async {
                              setState(() {
                                _isSavingProfile = true;
                              });
                              try {
                                final updatedProfile = await widget.apiService
                                    .updateMe({
                                      'display_name': displayNameController.text
                                          .trim(),
                                      'photo_url': photoUrl,
                                      'cover_url': coverUrl,
                                      'bio': bioController.text.trim(),
                                    });
                                if (!mounted) {
                                  return;
                                }
                                // Re-fetch /api/me so cover_url + bio stick after leaving the screen
                                Map<String, dynamic> refreshed = {
                                  ...currentProfile,
                                  ...updatedProfile,
                                };
                                try {
                                  final me = await widget.apiService.fetchMe();
                                  if (me.isNotEmpty) {
                                    refreshed = {...refreshed, ...me};
                                  }
                                } catch (_) {}
                                setState(() {
                                  _userProfile = refreshed;
                                });
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Profile updated successfully',
                                    ),
                                  ),
                                );
                              } catch (_) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to update profile. Please try again.',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isSavingProfile = false;
                                  });
                                }
                              }
                            },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Save changes'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileName = _valueAsString(_userProfile?['display_name']).trim();
    final displayName = profileName.isNotEmpty
        ? profileName
        : (widget.profile.displayName.trim().isNotEmpty
            ? widget.profile.displayName
            : widget.profile.username);
    final usernameHandle = widget.profile.username
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('@', '');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient Header — fixed overflow by using smaller avatar + tighter spacing
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A3A52),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    _valueAsString(_userProfile?['cover_url']).isNotEmpty
                    ? BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            widget.apiService.resolveAssetUrl(
                              _valueAsString(_userProfile?['cover_url']),
                            ),
                          ),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.35),
                            BlendMode.darken,
                          ),
                        ),
                      )
                    : const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A3A52), Color(0xFF2D5A7A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage:
                              _valueAsString(
                                _userProfile?['photo_url'],
                              ).isNotEmpty
                              ? NetworkImage(
                                  widget.apiService.resolveAssetUrl(
                                    _valueAsString(_userProfile?['photo_url']),
                                  ),
                                )
                              : null,
                          child:
                              _valueAsString(_userProfile?['photo_url']).isEmpty
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'U',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '@$usernameHandle',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ),
                            if (widget.profile.id == null ||
                                widget.profile.id ==
                                    (_userProfile?['id'] as int?))
                              OutlinedButton.icon(
                                onPressed: _showEditProfileSheet,
                                icon: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final authorId = widget.profile.id!;
                                    try {
                                      if (_isFollowing) {
                                        await widget.apiService.unfollowAuthor(
                                          authorId,
                                        );
                                        setState(() {
                                          _isFollowing = false;
                                          _followerCount =
                                              (_followerCount ??
                                                  widget.profile.followers) -
                                              1;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unfollowed author'),
                                          ),
                                        );
                                      } else {
                                        await widget.apiService.followAuthor(
                                          authorId,
                                        );
                                        setState(() {
                                          _isFollowing = true;
                                          _followerCount =
                                              (_followerCount ??
                                                  widget.profile.followers) +
                                              1;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Now following'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    _isFollowing
                                        ? Icons.person_remove_alt_1_outlined
                                        : Icons.person_add_alt_1_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _isFollowing ? 'Unfollow' : 'Follow',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatCard(
                    label: 'Following',
                    value: widget.profile.following.toString(),
                  ),
                  _StatCard(
                    label: 'Followers',
                    value: widget.profile.followers.toString(),
                  ),
                  _StatCard(
                    label: 'Blocked',
                    value: widget.profile.blocked.toString(),
                  ),
                ],
              ),
            ),
          ),

          // Tabs — wrapped in Material to fix "No Material widget found"
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              child: Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.brand,
                  unselectedLabelColor: AppTheme.muted,
                  indicatorColor: AppTheme.brand,
                  tabs: const [
                    Tab(text: 'About'),
                    Tab(text: 'Stories'),
                    Tab(text: 'Wall'),
                    Tab(text: 'Activity'),
                    Tab(text: 'Reviews'),
                  ],
                ),
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AboutTab(
                  profile: widget.profile,
                  apiService: widget.apiService,
                  bio: _valueAsString(_userProfile?['bio']),
                  currentReads: _currentReads,
                ),
                _StoriesTab(
                  storiesFuture: _storiesFuture,
                  apiService: widget.apiService,
                ),
                _WallTab(messagesFuture: _wallFuture),
                _ActivityTab(notificationsFuture: _activityFuture),
                _ReviewsTab(
                  reviews: _myReviews,
                  apiService: widget.apiService,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.brand,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.profile,
    required this.apiService,
    this.bio = '',
    this.currentReads = const [],
  });

  final ProfileModel profile;
  final ApiService apiService;
  final String bio;
  final List<LibraryEntryModel> currentReads;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Currently Reading',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (currentReads.isEmpty)
          Text(
            'No books in progress — tap Read Now on a story to start.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: currentReads.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final e = currentReads[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
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
                  child: SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: e.book.coverPath.isNotEmpty
                                ? Image.network(
                                    apiService.resolveAssetUrl(e.book.coverPath),
                                    width: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: Color(0xFFE4E4E4)),
                                  )
                                : const ColoredBox(color: Color(0xFFE4E4E4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 28),
        Text(
          'Stats',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatsPanel(
              icon: Icons.menu_book_outlined,
              label: 'Chapters Read',
              value: profile.chaptersRead.toString(),
              color: const Color(0xFF667EEA),
            ),
            _StatsPanel(
              icon: Icons.favorite_outline,
              label: 'Social Karma',
              value: profile.socialKarma.toString(),
              color: const Color(0xFFFF6B9D),
            ),
            _StatsPanel(
              icon: Icons.local_fire_department_outlined,
              label: 'Day Streak',
              value: profile.dayStreak.toString(),
              color: const Color(0xFFFFB84D),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Reading Lists',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (profile.readingLists.isEmpty)
          Text(
            'No reading lists yet',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: profile.readingLists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _ReadingListPreview(
                list: profile.readingLists[index],
                apiService: apiService,
              ),
            ),
          ),
        const SizedBox(height: 32),
        Text(
          'About Me',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            bio.trim().isEmpty ? 'No bio added yet' : bio.trim(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: const Color(0xFF555555),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: AppTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingListPreview extends StatelessWidget {
  const _ReadingListPreview({required this.list, required this.apiService});

  final ReadingListModel list;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF5F5F5),
              ),
              child: list.coverPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        apiService.resolveAssetUrl(list.coverPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Color(0xFFF5F5F5)),
                      ),
                    )
                  : Icon(
                      Icons.library_books_outlined,
                      color: AppTheme.muted.withValues(alpha: 0.3),
                      size: 48,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            list.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _StoriesTab extends StatelessWidget {
  const _StoriesTab({required this.storiesFuture, required this.apiService});

  final Future<List<Map<String, dynamic>>> storiesFuture;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: storiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stories = snapshot.data ?? const <Map<String, dynamic>>[];
        if (stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 48,
                  color: AppTheme.muted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No published stories yet',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final story = stories[index];
            final cover = story['cover_path']?.toString() ?? '';
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                onTap: () {
                  final id = (story['id'] as num?)?.toInt();
                  if (id == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoryDetailScreen(
                        apiService: apiService,
                        book: BookDetailModel.fromMap(story),
                      ),
                    ),
                  );
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    final id = (story['id'] as num?)?.toInt();
                    if (id == null) return;
                    if (v == 'read') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryDetailScreen(
                            apiService: apiService,
                            book: BookDetailModel.fromMap(story),
                          ),
                        ),
                      );
                    } else if (v == 'chapters') {
                      List<Map<String, dynamic>> chapters = const [];
                      try {
                        chapters = await apiService.fetchStoryChapters(id);
                      } catch (_) {}
                      if (!context.mounted) return;
                      final choice = await showModalBottomSheet<Object>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Chapters',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                if (chapters.isEmpty)
                                  const Text('No chapters yet'),
                                for (final c in chapters)
                                  ListTile(
                                    title: Text(
                                      (c['title'] ??
                                              'Chapter ${(c['chapter_number'] as num?)?.toInt() ?? 0}')
                                          .toString(),
                                    ),
                                    onTap: () => Navigator.pop(ctx, c),
                                  ),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pop(ctx, 'new'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add new chapter'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (!context.mounted || choice == null) return;
                      if (choice == 'new') {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EditChapterScreen(
                              apiService: apiService,
                              storyId: id,
                              createNew: true,
                            ),
                          ),
                        );
                      } else if (choice is Map<String, dynamic>) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EditChapterScreen(
                              apiService: apiService,
                              storyId: id,
                              chapterId: (choice['id'] as num?)?.toInt(),
                              chapterNumber:
                                  (choice['chapter_number'] as num?)?.toInt(),
                              chapterTitle:
                                  (choice['title'] ?? 'Chapter').toString(),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'read', child: Text('Read / view')),
                    PopupMenuItem(
                      value: 'chapters',
                      child: Text('Manage chapters'),
                    ),
                  ],
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: cover.isNotEmpty
                      ? Image.network(
                          apiService.resolveAssetUrl(cover),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFFF5F5F5)),
                        )
                      : const SizedBox(
                          width: 64,
                          height: 64,
                          child: ColoredBox(color: Color(0xFFF5F5F5)),
                        ),
                ),
                title: Text(story['title'] as String? ?? 'Untitled story'),
                subtitle: Text(story['author'] as String? ?? 'Unknown author'),
                trailing: Text(
                  story['status_text'] as String? ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WallTab extends StatelessWidget {
  const _WallTab({required this.messagesFuture});

  final Future<List<Map<String, dynamic>>> messagesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? const <Map<String, dynamic>>[];
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppTheme.muted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No wall posts yet',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final message = messages[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['sender'] as String? ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message['message'] as String? ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message['created_at'] as String? ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.notificationsFuture});

  final Future<List<Map<String, dynamic>>> notificationsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data ?? const <Map<String, dynamic>>[];
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 48,
                  color: AppTheme.muted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification['message'] as String? ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notification['created_at'] as String? ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviews, required this.apiService});

  final List<Map<String, dynamic>> reviews;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 48,
              color: AppTheme.muted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate a book from its story page to see it here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = reviews[index];
        final book = Map<String, dynamic>.from(
          (r['book'] as Map?) ?? const {},
        );
        final title = (book['title'] ?? 'Untitled').toString();
        final author = (book['author'] ?? '').toString();
        final cover = (book['cover_path'] ?? '').toString();
        final rating = r['rating'];
        final comment = (r['comment'] ?? '').toString();
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
          onTap: () {
            final id = (book['id'] as num?)?.toInt();
            if (id == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: apiService,
                  book: BookDetailModel.fromMap(book),
                ),
              ),
            );
          },
          leading: SizedBox(
            width: 44,
            height: 60,
            child: cover.isNotEmpty
                ? Image.network(
                    apiService.resolveAssetUrl(cover),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFE4E4E4)),
                  )
                : const ColoredBox(color: Color(0xFFE4E4E4)),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (author.isNotEmpty) author,
              if (rating != null) '★ $rating',
              if (comment.isNotEmpty) comment,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}
