/// HTTP client for the Zerexa Video upstream API.
///
/// The app talks directly to https://video.zerexa.net - a native client is
/// not subject to browser CORS restrictions, so no proxy is needed.
/// Auth uses a JWT bearer token persisted via [SharedPreferences].
library;

import 'package:dio/dio.dart';

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Normalises the various list/paginated shapes the upstream returns
/// into a plain [List] of JSON maps.
List<Map<String, dynamic>> asJsonList(dynamic data) {
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  if (data is Map<String, dynamic>) {
    for (final key in const ['items', 'data', 'results', 'videos', 'list']) {
      final v = data[key];
      if (v is List) return v.whereType<Map<String, dynamic>>().toList();
    }
    // Single-object responses.
    return [data];
  }
  return const [];
}

class ZerexaApi {
  ZerexaApi({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = onToken?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static const String defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://video.zerexa.net');

  final String _baseUrl;
  late final Dio _dio;

  /// Callback used to attach the current auth token to every request.
  String? Function()? onToken;

  String get baseUrl => _baseUrl;

  /// Resolves upstream-relative asset paths (covers, gravatars, subtitles)
  /// into absolute URLs.
  String resolveAsset(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$_baseUrl$path';
    return '$_baseUrl/$path';
  }

  // ---------- low level ----------

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      // Null-valued query params are dropped entirely: the upstream API
      // treats literal "null" strings as real filters (e.g.
      // ?category=null returns an empty list), which used to blank out
      // the whole home feed.
      final filteredQuery = query == null
          ? null
          : Map.fromEntries(query.entries
              .where((e) => e.value != null)
              .map((e) => MapEntry(e.key, '${e.value}')));
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: filteredQuery,
        options: Options(method: method),
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['message'] is String) {
        // Upstream error payloads sometimes come with HTTP 200; surface them.
        final code = data['code'] ?? data['status'];
        if (code is int && code >= 400) {
          throw ApiException('${data['message']}', code);
        }
      }
      return res.data;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      var msg = '网络错误';
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final m = data['message'] ?? data['error'];
        if (m != null) msg = '$m';
      } else if (data is String && data.isNotEmpty && data.length < 200) {
        msg = data;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        msg = '请求超时，请稍后重试';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = '无法连接服务器';
      }
      throw ApiException(msg, code);
    }
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> _post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> _put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> _delete(String path) => _send('DELETE', path);

  // ---------- auth ----------

  /// Server-advertised captcha settings. The GeeTest secret key itself
  /// lives on the server; the client only ever sees the public id.
  Future<CaptchaConfig> captchaConfig() async {
    try {
      final data = await _get('/api/auth/captcha-config');
      if (data is Map<String, dynamic>) {
        return CaptchaConfig.fromJson(data);
      }
    } catch (_) {
      // fall through to the hardcoded fallback below
    }
    return CaptchaConfig.fallback;
  }

  Future<bool> ping() async {
    final data = await _get('/api/ping');
    if (data is Map<String, dynamic>) return data['pong'] == true;
    return true;
  }

  Future<bool> checkUsername(String username) async {
    final data = await _get('/api/auth/check-username',
        query: {'username': username});
    if (data is Map<String, dynamic>) return data['available'] == true;
    return false;
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
    Map<String, dynamic>? geetest,
  }) async {
    final data = await _post('/api/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      if (geetest != null) 'geetest': geetest,
    });
    if (data is Map<String, dynamic>) return data['token'] as String?;
    return null;
  }

  Future<String?> login({
    required String identifier,
    required String password,
    Map<String, dynamic>? geetest,
  }) async {
    final data = await _post('/api/auth/login', body: {
      'identifier': identifier,
      'password': password,
      if (geetest != null) 'geetest': geetest,
    });
    if (data is Map<String, dynamic>) return data['token'] as String?;
    return null;
  }

  Future<void> logout() => _post('/api/auth/logout');

  // ---------- user ----------

  Future<UserInfo> me() async =>
      UserInfo.fromJson((await _get('/api/user')) as Map<String, dynamic>);

  Future<UserInfo> getUserPublic(int uid) async =>
      UserInfo.fromJson((await _get('/api/user/$uid')) as Map<String, dynamic>);

  Future<List<VideoItem>> history() async =>
      asJsonList(await _get('/api/user/history')).map(VideoItem.fromJson).toList();

  Future<List<VideoItem>> favorites() async =>
      asJsonList(await _get('/api/user/favorites')).map(VideoItem.fromJson).toList();

  // ---------- videos ----------

  Future<List<VideoItem>> listVideos({
    int? limit,
    int? offset,
    String? category,
    String? sort,
  }) async =>
      asJsonList(await _get('/api/videos', query: {
        'limit': limit,
        'offset': offset,
        'category': category,
        'sort': sort,
      })).map(VideoItem.fromJson).toList();

  Future<VideoItem> getVideo(String id) async =>
      VideoItem.fromJson((await _get('/api/videos/$id')) as Map<String, dynamic>);

  Future<void> likeVideo(String id) async =>
      _post('/api/videos/$id/like');

  Future<void> favoriteVideo(String id) async =>
      _post('/api/favorites', body: {'video_id': id});

  Future<void> unfavoriteVideo(String id) async => _delete('/api/favorites/$id');

  Future<bool> checkFavorite(String id) async {
    final data = await _get('/api/favorites/$id/check');
    if (data is Map<String, dynamic>) return data['favorited'] == true;
    return false;
  }

  Future<void> coinVideo(String id, {int amount = 1}) async =>
      _post('/api/videos/$id/coin', body: {'amount': amount});

  Future<void> updateVideo(String id, Map<String, dynamic> body) async =>
      _put('/api/videos/$id', body: body);

  Future<void> deleteVideo(String id) async => _delete('/api/videos/$id');

  // ---------- comments & danmaku ----------

  Future<List<CommentItem>> listComments(String id,
      {int limit = 50, int offset = 0}) async {
    final data = await _get('/api/videos/$id/comments',
        query: {'limit': limit, 'offset': offset});
    if (data is Map<String, dynamic>) {
      final items = data['items'] as List<dynamic>? ?? const [];
      return items.whereType<Map<String, dynamic>>().map(CommentItem.fromJson).toList();
    }
    return asJsonList(data).map(CommentItem.fromJson).toList();
  }

  Future<CommentItem> postComment(String id, String content,
      {String? parentId}) async {
    final data = await _post('/api/videos/$id/comments', body: {
      'content': content,
      'parent_id': parentId,
    });
    return CommentItem.fromJson(data as Map<String, dynamic>);
  }

  Future<List<DanmakuItem>> listDanmaku(String id) async =>
      asJsonList(await _get('/api/videos/$id/danmaku'))
          .map(DanmakuItem.fromJson)
          .toList();

  // ---------- search & announcements ----------

  Future<List<VideoItem>> search(String q, {int limit = 50, int offset = 0}) async {
    final data = await _get('/api/search',
        query: {'q': q, 'limit': limit, 'offset': offset});
    if (data is Map<String, dynamic>) {
      final videos = data['videos'] as List<dynamic>? ?? const [];
      return videos.whereType<Map<String, dynamic>>().map(VideoItem.fromJson).toList();
    }
    return asJsonList(data).map(VideoItem.fromJson).toList();
  }

  Future<List<Announcement>> listAnnouncements() async =>
      asJsonList(await _get('/api/announcements'))
          .map(Announcement.fromJson)
          .toList();

  // ---------- articles ----------

  Future<List<ArticleItem>> listArticles({
    int? limit,
    int? offset,
    String? category,
  }) async =>
      asJsonList(await _get('/api/articles', query: {
        'limit': limit,
        'offset': offset,
        'category': category,
      })).map(ArticleItem.fromJson).toList();

  Future<ArticleItem> getArticle(String id) async =>
      ArticleItem.fromJson((await _get('/api/articles/$id')) as Map<String, dynamic>);

  Future<void> createArticle(Map<String, dynamic> body) async =>
      _post('/api/articles', body: body);

  Future<void> updateArticle(String id, Map<String, dynamic> body) async =>
      _put('/api/articles/$id', body: body);

  Future<void> deleteArticle(String id) async => _delete('/api/articles/$id');

  Future<void> likeArticle(String id) async => _post('/api/articles/$id/like');

  // ---------- dynamics ----------

  Future<List<DynamicItem>> listDynamics({int? limit, int? offset}) async =>
      asJsonList(await _get('/api/dynamics', query: {
        'limit': limit,
        'offset': offset,
      })).map(DynamicItem.fromJson).toList();

  Future<List<DynamicItem>> listDynamicsByUser(int uid,
          {int? limit, int? offset}) async =>
      asJsonList(await _get('/api/users/$uid/dynamics',
          query: {'limit': limit, 'offset': offset}))
          .map(DynamicItem.fromJson)
          .toList();

  Future<void> createDynamic(Map<String, dynamic> body) async =>
      _post('/api/dynamics', body: body);

  Future<void> deleteDynamic(String id) async => _delete('/api/dynamics/$id');

  Future<void> likeDynamic(String id) async => _post('/api/dynamics/$id/like');

  // ---------- conversations & messages ----------

  Future<List<Conversation>> listConversations() async =>
      asJsonList(await _get('/api/messages/conversations'))
          .map(Conversation.fromJson)
          .toList();

  Future<List<DirectMessage>> listMessages(String conversationId,
      {int limit = 100}) async {
    final data = await _get('/api/messages/conversations/$conversationId',
        query: {'limit': limit});
    return asJsonList(data).map(DirectMessage.fromJson).toList();
  }

  Future<DirectMessage> sendMessage({
    String? conversationId,
    int? recipientUid,
    required String content,
  }) async {
    final data = await _post('/api/messages', body: {
      if (conversationId != null) 'conversation_id': conversationId,
      if (recipientUid != null) 'recipient_uid': recipientUid,
      'content': content,
    });
    return DirectMessage.fromJson(data as Map<String, dynamic>);
  }

  Future<String> startConversation(int recipientUid) async {
    final data = await _post('/api/messages/conversations', body: {
      'recipient_uid': recipientUid,
    });
    if (data is Map<String, dynamic>) {
      return '${data['conversation_id'] ?? data['id'] ?? ''}';
    }
    return '';
  }

  Future<void> markConversationRead(String conversationId) async =>
      _post('/api/messages/conversations/$conversationId/read');

  // ---------- notifications ----------

  Future<List<SiteNotification>> listNotifications({int limit = 50}) async =>
      asJsonList(await _get('/api/notifications', query: {'limit': limit}))
          .map(SiteNotification.fromJson)
          .toList();

  Future<void> markNotificationRead(String id) async =>
      _post('/api/notifications/$id/read');

  Future<void> markAllNotificationsRead() async =>
      _post('/api/notifications/read-all');

  // ---------- tickets ----------

  Future<List<Ticket>> listTickets({String? status, int limit = 50}) async =>
      asJsonList(await _get('/api/tickets', query: {
        'status': status,
        'limit': limit,
      })).map(Ticket.fromJson).toList();

  Future<Ticket> getTicket(String id) async =>
      Ticket.fromJson((await _get('/api/tickets/$id')) as Map<String, dynamic>);

  Future<void> createTicket(Map<String, dynamic> body) async =>
      _post('/api/tickets', body: body);

  Future<void> replyTicket(String id, String content) async =>
      _post('/api/tickets/$id/replies', body: {'content': content});

  Future<void> closeTicket(String id) async => _post('/api/tickets/$id/close');

  Future<void> reopenTicket(String id) async => _post('/api/tickets/$id/reopen');

  // ---------- votes ----------

  Future<List<Vote>> listVotes({String? status, int limit = 50}) async =>
      asJsonList(await _get('/api/votes', query: {
        'status': status,
        'limit': limit,
      })).map(Vote.fromJson).toList();

  Future<Vote> getVote(String id) async =>
      Vote.fromJson((await _get('/api/votes/$id')) as Map<String, dynamic>);

  Future<void> castVote(String id, String optionId) async =>
      _post('/api/votes/$id/vote', body: {'option_id': optionId});

  // ---------- uploads ----------

  Future<UploadSession> initUpload(Map<String, dynamic> body) async =>
      UploadSession.fromJson(
          (await _post('/api/uploads/init', body: body)) as Map<String, dynamic>);

  Future<dynamic> completeUpload(Map<String, dynamic> body) async =>
      _post('/api/uploads/complete', body: body);

  Future<void> abortUpload(String uploadId) async =>
      _delete('/api/uploads/$uploadId');

  /// PUTs one chunk to a presigned URL and returns the ETag if present.
  Future<String?> putChunk(String url, List<int> bytes,
      {Map<String, String>? headers, void Function(int count, int total)? onProgress}) async {
    final res = await _dio.put<dynamic>(
      url,
      data: bytes,
      options: Options(
        headers: {...?headers, 'Content-Length': bytes.length},
      ),
      onSendProgress: (count, total) => onProgress?.call(count, total),
    );
    return res.headers.value('etag');
  }

  // ---------- subtitles ----------

  Future<List<SubtitleTrack>> listSubtitles(String videoId) async =>
      asJsonList(await _get('/api/videos/$videoId/subtitles'))
          .map(SubtitleTrack.fromJson)
          .toList();

  // ---------- collections ----------

  Future<List<CollectionItem>> listCollections({int? limit, int? offset}) async =>
      asJsonList(await _get('/api/collections', query: {
        'limit': limit,
        'offset': offset,
      })).map(CollectionItem.fromJson).toList();

  Future<CollectionItem> getCollection(String id) async => CollectionItem.fromJson(
      (await _get('/api/collections/$id')) as Map<String, dynamic>);

  Future<void> createCollection(Map<String, dynamic> body) async =>
      _post('/api/collections', body: body);

  Future<void> updateCollection(String id, Map<String, dynamic> body) async =>
      _put('/api/collections/$id', body: body);

  Future<void> deleteCollection(String id) async => _delete('/api/collections/$id');

  Future<void> addVideoToCollection(String collectionId, String videoId) async =>
      _post('/api/collections/$collectionId/videos', body: {'video_id': videoId});

  Future<void> removeVideoFromCollection(
          String collectionId, String videoId) async =>
      _delete('/api/collections/$collectionId/videos/$videoId');

  // ---------- reports ----------

  Future<void> reportUser(Map<String, dynamic> body) async =>
      _post('/api/reports', body: body);

  // ---------- admin ----------

  Future<List<VideoItem>> adminListVideos({String? status, int limit = 50}) async =>
      asJsonList(await _get('/api/admin/videos', query: {
        'status': status,
        'limit': limit,
      })).map(VideoItem.fromJson).toList();

  Future<List<AdminUser>> adminListUsers(
      {String? role, bool? banned, int limit = 100}) async {
    final data = await _get('/api/admin/users', query: {
      'role': role,
      if (banned != null) 'banned': banned,
      'limit': limit,
    });
    return asJsonList(data).map(AdminUser.fromJson).toList();
  }

  Future<List<AdminReport>> adminListReports({String? status, int limit = 100}) async =>
      asJsonList(await _get('/api/admin/reports', query: {
        'status': status,
        'limit': limit,
      })).map(AdminReport.fromJson).toList();

  Future<List<Announcement>> adminListAnnouncements() async =>
      asJsonList(await _get('/api/admin/announcements'))
          .map(Announcement.fromJson)
          .toList();

  Future<void> adminCreateAnnouncement(Map<String, dynamic> body) async =>
      _post('/api/admin/announcements', body: body);

  Future<void> adminUpdateAnnouncement(String id, Map<String, dynamic> body) async =>
      _post('/api/admin/announcements',
          body: {...body, 'id': id, 'action': 'update'});

  Future<void> adminDeleteAnnouncement(String id) async =>
      _post('/api/admin/announcements', body: {'id': id, 'action': 'delete'});

  Future<void> adminUserAction(Map<String, dynamic> body) async =>
      _post('/api/admin/users/action', body: body);

  Future<void> adminBanUser(int uid, {String? reason, String? duration}) async =>
      adminUserAction({
        'uid': uid,
        'action': 'ban',
        if (reason != null) 'reason': reason,
        if (duration != null) 'duration': duration,
      });

  Future<void> adminUnbanUser(int uid) async =>
      adminUserAction({'uid': uid, 'action': 'unban'});

  Future<void> adminSetUserRole(int uid, String role) async =>
      adminUserAction({'uid': uid, 'action': 'set_role', 'role': role});

  Future<void> adminCloseReport(String id, {String? resolution}) async =>
      _post('/api/admin/reports/$id/close',
          body: resolution != null ? {'resolution': resolution} : null);

  Future<void> adminResolveReport(String id, {String? resolution}) async =>
      _post('/api/admin/reports/$id/resolve',
          body: resolution != null ? {'resolution': resolution} : null);
}
