// lib/api/notes/notes_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class NoteSummary {
  final String id;
  final String title;
  final String content;
  final String? folderId;
  final bool isPinned;
  final DateTime? lastAccessedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteSummary({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    required this.isPinned,
    required this.lastAccessedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteSummary.fromJson(Map<String, dynamic> json) {
    return NoteSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      folderId: json['folder_id'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get preview {
    final String flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return 'No content yet';
    return flat.length > 120 ? '${flat.substring(0, 120)}…' : flat;
  }
}

class FolderSummary {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FolderSummary({
    required this.id,
    required this.name,
    required this.parentFolderId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FolderSummary.fromJson(Map<String, dynamic> json) {
    return FolderSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      parentFolderId: json['parent_folder_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class NoteVersionSummary {
  final String id;
  final String content;
  final DateTime createdAt;

  const NoteVersionSummary({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory NoteVersionSummary.fromJson(Map<String, dynamic> json) {
    return NoteVersionSummary(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NoteDetail {
  final String id;
  final String title;
  final String content;
  final String? folderId;
  final bool isPinned;
  final DateTime? lastAccessedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoteVersionSummary> versions;

  const NoteDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    required this.isPinned,
    required this.lastAccessedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.versions,
  });

  factory NoteDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawVersions =
        json['versions'] as List<dynamic>? ?? const [];
    return NoteDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      folderId: json['folder_id'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      versions: rawVersions
          .map((dynamic e) =>
              NoteVersionSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class QuickCaptureSummary {
  final String id;
  final String rawText;
  final bool isProcessed;
  final DateTime createdAt;

  const QuickCaptureSummary({
    required this.id,
    required this.rawText,
    required this.isProcessed,
    required this.createdAt,
  });

  factory QuickCaptureSummary.fromJson(Map<String, dynamic> json) {
    return QuickCaptureSummary(
      id: json['id'] as String,
      rawText: json['raw_text'] as String? ?? '',
      isProcessed: json['is_processed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotesApi {
  final Dio _dio;

  NotesApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<List<NoteSummary>> recent({int limit = 3}) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notes/recent',
        queryParameters: {'limit': limit},
      );
      final List<dynamic> items = response.data as List<dynamic>;
      return items
          .map((e) => NoteSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<NoteSummary>> list({
    String? folderId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notes',
        queryParameters: {
          if (folderId != null) 'folder_id': folderId,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => NoteSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NoteDetail> getDetail(String noteId) async {
    try {
      final Response<dynamic> response = await _dio.get('/notes/$noteId');
      return NoteDetail.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NoteSummary> create({
    required String title,
    String? content,
    String? folderId,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/notes',
        data: {
          'title': title,
          'content': content ?? '',
          if (folderId != null) 'folder_id': folderId,
        },
      );
      return NoteSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NoteSummary> update(
    String noteId, {
    String? title,
    String? content,
    String? folderId,
    bool? isPinned,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/notes/$noteId',
        data: {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          if (folderId != null) 'folder_id': folderId,
          if (isPinned != null) 'is_pinned': isPinned,
        },
      );
      return NoteSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> delete(String noteId) async {
    try {
      await _dio.delete('/notes/$noteId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<FolderSummary>> listFolders({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notes/folders',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              FolderSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<FolderSummary> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/notes/folders',
        data: {
          'name': name,
          if (parentFolderId != null) 'parent_folder_id': parentFolderId,
        },
      );
      return FolderSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<QuickCaptureSummary> createQuickCapture(String rawText) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/notes/quick-captures',
        data: {'raw_text': rawText},
      );
      return QuickCaptureSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<QuickCaptureSummary>> listQuickCaptures({
    bool unprocessedOnly = false,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notes/quick-captures',
        queryParameters: {
          'unprocessed_only': unprocessedOnly,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => QuickCaptureSummary.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}