import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.apiService, this.story});

  final ApiService apiService;
  final Map<String, dynamic>? story;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _authorController = TextEditingController();
  final _genreController = TextEditingController();
  final _tagsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;
  String _coverPath = '';
  final List<String> _selectedTags = [];
  List<String> _availableTags = const [];
  bool _loadingTags = false;

  bool get _isEditing => widget.story != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.story!['title']?.toString() ?? '';
      _summaryController.text = widget.story!['description']?.toString() ?? '';
      _authorController.text = widget.story!['author']?.toString() ?? '';
      _genreController.text = widget.story!['genre']?.toString() ?? '';
      _coverPath = widget.story!['cover_path']?.toString() ?? '';
      final existing = (widget.story!['tags'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          <String>[];
      _selectedTags.addAll(existing.take(3));
      _tagsController.text = _selectedTags.join(', ');
    }
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    setState(() => _loadingTags = true);
    try {
      final items = await widget.apiService.fetchTags();
      if (!mounted) return;
      setState(() {
        _availableTags = items
            .map((e) => (e['name'] as String? ?? '').trim())
            .where((n) => n.isNotEmpty)
            .toList();
        _loadingTags = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  void _toggleTag(String name) {
    setState(() {
      if (_selectedTags.contains(name)) {
        _selectedTags.remove(name);
      } else if (_selectedTags.length < 3) {
        _selectedTags.add(name);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 hashtags per story')),
        );
        return;
      }
      _tagsController.text = _selectedTags.join(', ');
    });
  }

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final payload = await widget.apiService.uploadWriterImage(bytes, picked.name);
    final path = payload['path']?.toString() ?? '';
    if (!mounted || path.isEmpty) return;
    setState(() => _coverPath = path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cover image uploaded')),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _authorController.dispose();
    _genreController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final author = _authorController.text.trim();
    final genre = _genreController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'title': title,
        'description': summary,
        'author': author.isEmpty ? 'Me' : author,
        'genre': genre.isEmpty ? 'Fiction' : genre,
        'cover_path': _coverPath,
        'tags': List<String>.from(_selectedTags.take(3)),
      };

      if (_isEditing) {
        await widget.apiService.updateWriterStory(
          widget.story!['id'] as int,
          payload,
        );
      } else {
        await widget.apiService.createWriterStory(payload);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Story' : 'Create Story'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _coverPath.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(
                            widget.apiService.resolveAssetUrl(_coverPath),
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _coverPath.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('Add cover image'),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'TITLE',
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Story title',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'AUTHOR',
              child: TextField(
                controller: _authorController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Author name',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'GENRE',
              child: TextField(
                controller: _genreController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'e.g. Romance, Fantasy...',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'HASHTAGS (max 3)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingTags)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_selectedTags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedTags
                          .map(
                            (t) => InputChip(
                              label: Text(t.startsWith('#') ? t : '#$t'),
                              onDeleted: () => _toggleTag(t),
                              backgroundColor: const Color(0xFFFFF0EE),
                              labelStyle: const TextStyle(
                                color: Color(0xFFE85D4C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  if (_availableTags.isEmpty && !_loadingTags)
                    const Text(
                      'No hashtags available yet. Ask an admin to create some.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _availableTags
                          .where((t) => !_selectedTags.contains(t))
                          .map(
                            (t) => ActionChip(
                              label: Text(t.startsWith('#') ? t : '#$t'),
                              onPressed: () => _toggleTag(t),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'SUMMARY',
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _summaryController,
                builder: (context, value, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _summaryController,
                        maxLines: 6,
                        maxLength: 640,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText:
                              'Enter summary here - a longer description of what your story is about',
                          hintStyle: TextStyle(color: AppTheme.muted),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                      Text(
                        '${value.text.length}/640',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Create Story',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
