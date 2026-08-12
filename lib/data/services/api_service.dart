import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_bootstrap.dart';

class ApiService {
  ApiService();

  String? _authToken;
  String? get authTokenForPersistence => _authToken;
  void setAuthToken(String? token) { _authToken = token; }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://10.0.2.2:8000';
  }

  Map<String, String> get _authHeaders {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null && _authToken!.isNotEmpty) h['Authorization'] = 'Bearer $_authToken';
    return h;
  }

  String resolveAssetUrl(String path) {
    if (path.isEmpty) return path;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final clean = trimmed.split('?').first.split('#').first;
    if (clean.contains('story_card_images/') || clean.contains('/uploads/') || clean.contains('\\uploads\\')) {
      final filename = clean.split('/').last.split('\\').last;
      if (filename.isNotEmpty) return '$_baseUrl/uploads/$filename';
    }
    if (!clean.startsWith('/')) {
      if (clean.startsWith('uploads/')) return '$_baseUrl/$clean';
      return '$_baseUrl/uploads/$clean';
    }
    if (clean.startsWith('/uploads/')) return '$_baseUrl$clean';
    final filename = clean.split('/').last;
    if (filename.contains('.') && !clean.contains('/api/')) return '$_baseUrl/uploads/$filename';
    return '$_baseUrl$clean';
  }

  Future<http.Response> _get(String path, {Duration? timeout}) async {
    return http.get(Uri.parse('$_baseUrl$path'), headers: _authHeaders).timeout(timeout ?? const Duration(seconds: 12));
  }
  Future<http.Response> _post(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    return http.post(Uri.parse('$_baseUrl$path'), headers: _authHeaders, body: jsonEncode(body)).timeout(timeout ?? const Duration(seconds: 12));
  }
  Future<http.Response> _put(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    return http.put(Uri.parse('$_baseUrl$path'), headers: _authHeaders, body: jsonEncode(body)).timeout(timeout ?? const Duration(seconds: 12));
  }
  Future<http.Response> _delete(String path, {Duration? timeout}) async {
    return http.delete(Uri.parse('$_baseUrl$path'), headers: _authHeaders).timeout(timeout ?? const Duration(seconds: 12));
  }
  void _ensureSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<String> fetchContentVersion() async {
    try {
      final r = await _get('/api/content/version', timeout: const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is Map) return (p['version'] ?? p['content_version'] ?? '').toString();
        return p.toString();
      }
    } catch (_) {}
    return '';
  }

  Future<AppBootstrap> fetchBootstrap() async {
    final r = await _get('/api/bootstrap');
    _ensureSuccessResponse(r);
    return AppBootstrap.fromMap(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final r = await _get('/api/me', timeout: const Duration(seconds: 6));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    try {
      final r = await _get('/api/users/$userId');
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final r = await _put('/api/me', payload, timeout: const Duration(seconds: 8));
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadUserImage(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/me/upload-image'));
    req.headers.addAll(_authHeaders);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final r = await http.Response.fromStream(streamed);
      if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>> uploadWriterImage(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/write/upload-image'));
    req.headers.addAll(_authHeaders);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final r = await http.Response.fromStream(streamed);
      if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/support/upload-attachment'));
    req.headers.addAll(_authHeaders);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final r = await http.Response.fromStream(streamed);
      if (r.statusCode >= 200 && r.statusCode < 300) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<void> submitSupportRequest(Map<String, dynamic> payload) async {
    final r = await _post('/api/support', payload);
    _ensureSuccessResponse(r);
  }

  Future<Map<String, dynamic>> verifyGoogleSignIn({required String idToken, String? displayName, String? email, String? photoUrl}) async {
    final r = await _post('/api/auth/google', {'id_token': idToken, if (displayName != null) 'display_name': displayName, if (email != null) 'email': email, if (photoUrl != null) 'photo_url': photoUrl});
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmailSignIn(String email) async {
    final r = await _post('/api/auth/email', {'email': email});
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyGuestSignIn() async {
    final r = await _post('/api/auth/guest', {});
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> fetchPublicBook(int bookId) async {
    try {
      final r = await _get('/api/books/$bookId');
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapters(int storyId) async {
    try {
      final r = await _get('/api/write/stories/$storyId/chapters');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchBookReviews(int bookId) async {
    try {
      final r = await _get('/api/books/$bookId/reviews');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(p['items'] as List? ?? []);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> createBookReview(int bookId, Map<String, dynamic> payload) async {
    final r = await _post('/api/books/$bookId/reviews', payload);
    _ensureSuccessResponse(r);
  }

  Future<List<Map<String, dynamic>>> fetchBooksByTag(String tagName) async {
    try {
      final encoded = Uri.encodeComponent(tagName.trim().replaceFirst('#', ''));
      final r = await _get('/api/tags/$encoded/books');
      if (r.statusCode != 200) return const [];
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(p['items'] as List? ?? []);
    } catch (_) { return const []; }
  }

  Future<List<Map<String, dynamic>>> fetchAuthorBooks(int authorId, {int? excludeId}) async {
    try {
      var path = '/api/authors/$authorId/books';
      if (excludeId != null) path += '?exclude_id=$excludeId';
      final r = await _get(path);
      if (r.statusCode != 200) return const [];
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(p['items'] as List? ?? []);
    } catch (_) { return const []; }
  }

  Future<bool> fetchAuthorFollowing(int authorId) async {
    try {
      final r = await _get('/api/authors/$authorId/follow');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body) as Map<String, dynamic>;
        return (p['following'] as bool?) ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> followAuthor(int authorId) async {
    final r = await _post('/api/authors/$authorId/follow', {});
    _ensureSuccessResponse(r);
  }

  Future<void> unfollowAuthor(int authorId) async {
    final r = await _delete('/api/authors/$authorId/follow');
    _ensureSuccessResponse(r);
  }

  Future<List<Map<String, dynamic>>> fetchWriterStories() async {
    try {
      final r = await _get('/api/write/stories');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>> createWriterStory(Map<String, dynamic> payload) async {
    final r = await _post('/api/write/stories', payload);
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> updateWriterStory(int id, Map<String, dynamic> payload) async {
    final r = await _put('/api/write/stories/$id', payload);
    _ensureSuccessResponse(r);
  }

  Future<void> deleteWriterStory(int id) async {
    final r = await _delete('/api/write/stories/$id');
    _ensureSuccessResponse(r);
  }

  Future<int?> createStoryChapter(int storyId, Map<String, dynamic> payload) async {
    final r = await _post('/api/write/stories/$storyId/chapters', payload);
    _ensureSuccessResponse(r);
    final p = jsonDecode(r.body) as Map<String, dynamic>;
    return (p['id'] as num?)?.toInt();
  }

  Future<void> updateStoryChapter(int chapterId, Map<String, dynamic> payload) async {
    final r = await _put('/api/write/chapters/$chapterId', payload);
    _ensureSuccessResponse(r);
  }

  Future<void> deleteStoryChapter(int chapterId) async {
    final r = await _delete('/api/write/chapters/$chapterId');
    _ensureSuccessResponse(r);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapterRevisions(int chapterId) async {
    try {
      final r = await _get('/api/write/chapters/$chapterId/revisions');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchReadingLists() async {
    try {
      final r = await _get('/api/reading-lists');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>> fetchReadingListDetail(int listId) async {
    try {
      final r = await _get('/api/reading-lists/$listId');
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return const {};
  }

  Future<List<Map<String, dynamic>>> fetchReadingListItems(int listId) async {
    final detail = await fetchReadingListDetail(listId);
    return List<Map<String, dynamic>>.from(detail['items'] as List? ?? []);
  }

  Future<Map<String, dynamic>> createReadingList(Map<String, dynamic> payload) async {
    final r = await _post('/api/reading-lists', payload);
    _ensureSuccessResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> addReadingListItem(int listId, int bookId) async {
    final r = await _post('/api/reading-lists/$listId/items', {'book_id': bookId});
    _ensureSuccessResponse(r);
  }

  Future<void> removeReadingListItem(int listId, int bookId) async {
    final r = await _delete('/api/reading-lists/$listId/items/$bookId');
    _ensureSuccessResponse(r);
  }

  Future<void> deleteReadingList(int listId) async {
    final r = await _delete('/api/reading-lists/$listId');
    _ensureSuccessResponse(r);
  }

  Future<List<Map<String, dynamic>>> fetchLibraryEntries() async {
    try {
      final r = await _get('/api/library');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> addLibraryEntry(Map<String, dynamic> payload) async {
    final r = await _post('/api/library', payload);
    _ensureSuccessResponse(r);
  }

  Future<void> updateLibraryEntry(int id, Map<String, dynamic> payload) async {
    final r = await _put('/api/library/$id', payload);
    _ensureSuccessResponse(r);
  }

  Future<void> deleteLibraryEntry(int id) async {
    final r = await _delete('/api/library/$id');
    _ensureSuccessResponse(r);
  }

  Future<List<Map<String, dynamic>>> searchStories({String query = '', String? genre, double minRating = 0}) async {
    try {
      final params = <String, String>{'query': query, 'min_rating': '$minRating'};
      if (genre != null && genre.isNotEmpty) params['genre'] = genre;
      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final r = await _get('/api/search?$qs');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchTags({String? q}) async {
    try {
      final path = q != null && q.isNotEmpty ? '/api/tags?q=${Uri.encodeComponent(q)}' : '/api/tags';
      final r = await _get(path);
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(p['items'] as List? ?? []);
      }
    } catch (_) {}
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({String? tab}) async {
    try {
      final path = tab != null && tab.isNotEmpty ? '/api/notifications?tab=$tab' : '/api/notifications';
      final r = await _get(path);
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchChatMessages() async {
    try {
      final r = await _get('/api/chat/messages');
      if (r.statusCode == 200) {
        final p = jsonDecode(r.body);
        if (p is List) return List<Map<String, dynamic>>.from(p);
        if (p is Map && p['items'] is List) return List<Map<String, dynamic>>.from(p['items'] as List);
      }
    } catch (_) {}
    return const [];
  }
}
