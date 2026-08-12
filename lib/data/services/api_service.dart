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

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://10.0.2.2:8000';
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  String resolveAssetUrl(String path) {
    if (path.isEmpty) return path;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final clean = trimmed.split('?').first.split('#').first;
    if (clean.contains('story_card_images/') ||
        clean.contains('/uploads/') ||
        clean.contains('\\uploads\\')) {
      final filename = clean.split('/').last.split('\\').last;
      if (filename.isNotEmpty) {
        return '$_baseUrl/uploads/$filename';
      }
    }
    if (!clean.startsWith('/')) {
      if (clean.startsWith('uploads/')) return '$_baseUrl/$clean';
      return '$_baseUrl/uploads/$clean';
    }
    if (clean.startsWith('/uploads/')) return '$_baseUrl$clean';
    final filename = clean.split('/').last;
    if (filename.contains('.') && !clean.contains('/api/')) {
      return '$_baseUrl/uploads/$filename';
    }
    return '$_baseUrl$clean';
  }

  Future<http.Response> _get(String path, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http.get(uri, headers: _authHeaders).timeout(timeout ?? const Duration(seconds: 12));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http
        .post(uri, headers: _authHeaders, body: jsonEncode(body))
        .timeout(timeout ?? const Duration(seconds: 12));
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http
        .put(uri, headers: _authHeaders, body: jsonEncode(body))
        .timeout(timeout ?? const Duration(seconds: 12));
  }

  Future<http.Response> _delete(String path, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$path');
    return http.delete(uri, headers: _authHeaders).timeout(timeout ?? const Duration(seconds: 12));
  }

  void _ensureSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final response = await _get('/api/me', timeout: const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    try {
      final response = await _get('/api/users/$userId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final response = await _put('/api/me', payload, timeout: const Duration(seconds: 8));
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadUserImage(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/me/upload-image'));
    request.headers.addAll(_authHeaders);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> fetchPublicBook(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapters(int storyId) async {
    try {
      final response = await _get('/api/write/stories/$storyId/chapters');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchBookReviews(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId/reviews');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>? ?? []);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchBooksByTag(String tagName) async {
    try {
      final encoded = Uri.encodeComponent(tagName.trim().replaceFirst('#', ''));
      final response = await _get('/api/tags/$encoded/books');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAuthorBooks(int authorId, {int? excludeId}) async {
    try {
      var path = '/api/authors/$authorId/books';
      if (excludeId != null) path += '?exclude_id=$excludeId';
      final response = await _get(path);
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>? ?? []);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<bool> fetchAuthorFollowing(int authorId) async {
    try {
      final response = await _get('/api/authors/$authorId/follow');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return (payload['following'] as bool?) ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> followAuthor(int authorId) async {
    final response = await _post('/api/authors/$authorId/follow', {});
    _ensureSuccessResponse(response);
  }

  Future<void> unfollowAuthor(int authorId) async {
    final response = await _delete('/api/authors/$authorId/follow');
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchWriterStories() async {
    try {
      final response = await _get('/api/write/stories');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchReadingLists() async {
    try {
      final response = await _get('/api/reading-lists');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> fetchReadingListDetail(int listId) async {
    try {
      final response = await _get('/api/reading-lists/$listId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchReadingListItems(int listId) async {
    final detail = await fetchReadingListDetail(listId);
    final items = detail['items'] as List<dynamic>? ?? [];
    return List<Map<String, dynamic>>.from(items);
  }

  Future<Map<String, dynamic>> createReadingList(String name) async {
    final response = await _post('/api/reading-lists', {'name': name});
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> addToReadingList(int listId, int bookId) async {
    final response = await _post('/api/reading-lists/$listId/items', {'book_id': bookId});
    _ensureSuccessResponse(response);
  }

  Future<AppBootstrap> fetchBootstrap() async {
    final response = await _get('/api/bootstrap');
    _ensureSuccessResponse(response);
    return AppBootstrap.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({String? tab}) async {
    try {
      final path = tab != null && tab.isNotEmpty ? '/api/notifications?tab=$tab' : '/api/notifications';
      final response = await _get(path);
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchChatMessages() async {
    try {
      final response = await _get('/api/chat/messages');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchLibrary() async {
    try {
      final response = await _get('/api/library');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> searchBooks({String query = '', String? genre, double minRating = 0}) async {
    try {
      final params = <String, String>{'query': query, 'min_rating': '$minRating'};
      if (genre != null && genre.isNotEmpty) params['genre'] = genre;
      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final response = await _get('/api/search?$qs');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is List) return List<Map<String, dynamic>>.from(payload);
        if (payload is Map && payload['items'] is List) {
          return List<Map<String, dynamic>>.from(payload['items'] as List);
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchTags({String? q}) async {
    try {
      final path = q != null && q.isNotEmpty ? '/api/tags?q=${Uri.encodeComponent(q)}' : '/api/tags';
      final response = await _get(path);
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>? ?? []);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createWriterStory(Map<String, dynamic> payload) async {
    final response = await _post('/api/write/stories', payload);
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateWriterStory(int id, Map<String, dynamic> payload) async {
    final response = await _put('/api/write/stories/$id', payload);
    _ensureSuccessResponse(response);
  }

  Future<Map<String, dynamic>> uploadWriterImage(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/write/upload-image'));
    request.headers.addAll(_authHeaders);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createChapter(int storyId, Map<String, dynamic> payload) async {
    final response = await _post('/api/write/stories/$storyId/chapters', payload);
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateChapter(int chapterId, Map<String, dynamic> payload) async {
    final response = await _put('/api/write/chapters/$chapterId', payload);
    _ensureSuccessResponse(response);
  }

  Future<Map<String, dynamic>> postReview(int bookId, Map<String, dynamic> payload) async {
    final response = await _post('/api/books/$bookId/reviews', payload);
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> googleAuth(String idToken) async {
    final response = await _post('/api/auth/google', {'id_token': idToken});
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
