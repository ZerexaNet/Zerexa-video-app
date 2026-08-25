/// Data models for the Zerexa Video API.
///
/// Every model mirrors the JSON shapes returned by https://video.zerexa.net.
/// Fields are nullable whenever the upstream may omit them, and all
/// constructors are lenient (`fromJson` ignores wrong types gracefully)
/// because the upstream API occasionally drifts between shapes.
library;

typedef VerificationBadge = String?;

class VideoItem {
  final String id;
  final String title;
  final int views;
  final String category;
  final DateTime? createdAt;
  final String? externalCoverUrl;
  final String? externalPlayerUrl;
  final String authorUsername;
  final int authorUid;
  final VerificationBadge authorVerificationBadge;
  final String? authorVerificationLabel;
  final String? authorGravatarUrl;
  final int likes;
  final int? favCount;
  final int? coinCount;
  final int confusionCount;
  final String streamUrl;
  final String? coverUrl;
  final String? description;
  final String? status;
  final String? ipLocation;

  const VideoItem({
    required this.id,
    required this.title,
    this.views = 0,
    this.category = '',
    this.createdAt,
    this.externalCoverUrl,
    this.externalPlayerUrl,
    this.authorUsername = '',
    this.authorUid = 0,
    this.authorVerificationBadge,
    this.authorVerificationLabel,
    this.authorGravatarUrl,
    this.likes = 0,
    this.favCount,
    this.coinCount,
    this.confusionCount = 0,
    this.streamUrl = '',
    this.coverUrl,
    this.description,
    this.status,
    this.ipLocation,
  });

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: '${j['id'] ?? j['video_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        views: _toInt(j['views']) ?? 0,
        category: '${j['category'] ?? ''}',
        createdAt: _toDate(j['created_at']),
        externalCoverUrl: j['external_cover_url'] as String?,
        externalPlayerUrl: j['external_player_url'] as String?,
        authorUsername: '${j['author_username'] ?? ''}',
        authorUid: _toInt(j['author_uid']) ?? 0,
        authorVerificationBadge: j['author_verification_badge'] as String?,
        authorVerificationLabel: j['author_verification_label'] as String?,
        authorGravatarUrl: j['author_gravatar_url'] as String?,
        likes: _toInt(j['likes']) ?? 0,
        favCount: _toInt(j['fav_count']),
        coinCount: _toInt(j['coin_count']),
        confusionCount: _toInt(j['confusion_count']) ?? 0,
        streamUrl: '${j['stream_url'] ?? j['url'] ?? ''}',
        coverUrl: j['cover_url'] as String?,
        description: j['description'] as String?,
        status: j['status'] as String?,
        ipLocation: (j['ip_location'] ?? j['author_ip_location']) as String?,
      );

  String get displayCover => externalCoverUrl ?? coverUrl ?? '';
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final bool isActive;
  final String createdBy;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.isActive = false,
    this.createdBy = '',
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        content: '${j['content'] ?? ''}',
        isActive: _toBool(j['is_active']) ?? false,
        createdBy: '${j['created_by'] ?? ''}',
        createdAt: _toDate(j['created_at']),
      );
}

class CommentItem {
  final String id;
  final String content;
  final DateTime? createdAt;
  final int authorUid;
  final String authorUsername;
  final String? authorGravatarUrl;
  final VerificationBadge authorVerificationBadge;
  final String? authorVerificationLabel;
  final String? parentId;
  final int likes;
  final bool liked;
  final List<CommentItem> replies;

  const CommentItem({
    required this.id,
    required this.content,
    this.createdAt,
    this.authorUid = 0,
    this.authorUsername = '',
    this.authorGravatarUrl,
    this.authorVerificationBadge,
    this.authorVerificationLabel,
    this.parentId,
    this.likes = 0,
    this.liked = false,
    this.replies = const [],
  });

  factory CommentItem.fromJson(Map<String, dynamic> j) => CommentItem(
        id: '${j['id'] ?? ''}',
        content: '${j['content'] ?? ''}',
        createdAt: _toDate(j['created_at']),
        authorUid: _toInt(j['author_uid']) ?? 0,
        authorUsername: '${j['author_username'] ?? ''}',
        authorGravatarUrl: j['author_gravatar_url'] as String?,
        authorVerificationBadge: j['author_verification_badge'] as String?,
        authorVerificationLabel: j['author_verification_label'] as String?,
        parentId: j['parent_id'] as String?,
        likes: _toInt(j['likes']) ?? 0,
        liked: _toBool(j['liked']) ?? false,
        replies: (j['replies'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CommentItem.fromJson)
            .toList(),
      );
}

class DanmakuItem {
  final String id;
  final String text;
  final double time;
  final String type;
  final int color;
  final String author;

  const DanmakuItem({
    this.id = '',
    required this.text,
    required this.time,
    this.type = 'scroll',
    this.color = 0xFFFFFFFF,
    this.author = '',
  });

  factory DanmakuItem.fromJson(Map<String, dynamic> j) => DanmakuItem(
        id: '${j['id'] ?? ''}',
        text: '${j['text'] ?? j['content'] ?? ''}',
        time: _toDouble(j['time']) ?? _toDouble(j['position']) ?? 0,
        type: '${j['type'] ?? 'scroll'}',
        color: _parseColor(j['color']),
        author: '${j['author_username'] ?? ''}',
      );
}

class UserInfo {
  final int uid;
  final String username;
  final String? email;
  final String? role;
  final String? bio;
  final String? gravatarUrl;
  final VerificationBadge verificationBadge;
  final String? verificationLabel;
  final DateTime? createdAt;
  final int? points;
  final bool? signedInToday;

  const UserInfo({
    required this.uid,
    required this.username,
    this.email,
    this.role,
    this.bio,
    this.gravatarUrl,
    this.verificationBadge,
    this.verificationLabel,
    this.createdAt,
    this.points,
    this.signedInToday,
  });

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        uid: _toInt(j['uid'] ?? j['id']) ?? 0,
        username: '${j['username'] ?? ''}',
        email: j['email'] as String?,
        role: j['role'] as String?,
        bio: j['bio'] as String?,
        gravatarUrl: (j['gravatar_url'] ?? j['avatar_url']) as String?,
        verificationBadge: (j['verification_badge'] ?? j['author_verification_badge']) as String?,
        verificationLabel: (j['verification_label'] ?? j['author_verification_label']) as String?,
        createdAt: _toDate(j['created_at']),
        points: _toInt(j['points']),
        signedInToday: _toBool(j['signed_in_today']),
      );

  bool get isAdmin {
    final r = (role ?? '').toLowerCase();
    return r == 'admin' || r == 'moderator' || r == 'superadmin' || r == 'super_admin';
  }
}

class AdminUser {
  final String id;
  final int uid;
  final String username;
  final String? email;
  final String? role;
  final bool banned;
  final int? points;
  final DateTime? createdAt;
  final String? ipLocation;
  final int videoCount;
  final int followerCount;
  final int followingCount;

  const AdminUser({
    required this.id,
    this.uid = 0,
    required this.username,
    this.email,
    this.role,
    this.banned = false,
    this.points,
    this.createdAt,
    this.ipLocation,
    this.videoCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: '${j['id'] ?? ''}',
        uid: _toInt(j['uid'] ?? j['id']) ?? 0,
        username: '${j['username'] ?? ''}',
        email: j['email'] as String?,
        role: j['role'] as String?,
        banned: _toBool(j['is_banned'] ?? j['banned']) ??
            ('${j['status'] ?? ''}' == 'banned'),
        points: _toInt(j['points']),
        createdAt: _toDate(j['created_at']),
        ipLocation: j['ip_location'] as String?,
        videoCount: _toInt(j['video_count']) ?? 0,
        followerCount: _toInt(j['follower_count']) ?? 0,
        followingCount: _toInt(j['following_count']) ?? 0,
      );
}

class AdminReport {
  final String id;
  final int reporterUid;
  final String reporterUsername;
  final String targetType;
  final String targetId;
  final String targetTitle;
  final String reason;
  final String status;
  final DateTime? createdAt;
  final String? resolution;

  const AdminReport({
    required this.id,
    this.reporterUid = 0,
    this.reporterUsername = '',
    this.targetType = '',
    this.targetId = '',
    this.targetTitle = '',
    this.reason = '',
    this.status = 'open',
    this.createdAt,
    this.resolution,
  });

  factory AdminReport.fromJson(Map<String, dynamic> j) => AdminReport(
        id: '${j['id'] ?? ''}',
        reporterUid: _toInt(j['reporter_uid']) ?? 0,
        reporterUsername: '${j['reporter_username'] ?? ''}',
        targetType: '${j['target_type'] ?? ''}',
        targetId: '${j['target_id'] ?? ''}',
        targetTitle: '${j['target_title'] ?? ''}',
        reason: '${j['reason'] ?? ''}',
        status: '${j['status'] ?? 'open'}',
        createdAt: _toDate(j['created_at']),
        resolution: j['resolution'] as String?,
      );
}

class ArticleItem {
  final String id;
  final String title;
  final String? summary;
  final String? coverUrl;
  final String? category;
  final int views;
  final int likes;
  final int comments;
  final String authorUsername;
  final int authorUid;
  final String? authorGravatarUrl;
  final VerificationBadge authorVerificationBadge;
  final DateTime? createdAt;
  final String? status;
  final String content;
  final bool liked;

  const ArticleItem({
    required this.id,
    required this.title,
    this.summary,
    this.coverUrl,
    this.category,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.authorUsername = '',
    this.authorUid = 0,
    this.authorGravatarUrl,
    this.authorVerificationBadge,
    this.createdAt,
    this.status,
    this.content = '',
    this.liked = false,
  });

  factory ArticleItem.fromJson(Map<String, dynamic> j) => ArticleItem(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        summary: j['summary'] as String?,
        coverUrl: j['cover_url'] as String?,
        category: j['category'] as String?,
        views: _toInt(j['views']) ?? 0,
        likes: _toInt(j['likes']) ?? 0,
        comments: _toInt(j['comments']) ?? 0,
        authorUsername: '${j['author_username'] ?? ''}',
        authorUid: _toInt(j['author_uid']) ?? 0,
        authorGravatarUrl: j['author_gravatar_url'] as String?,
        authorVerificationBadge: j['author_verification_badge'] as String?,
        createdAt: _toDate(j['created_at']),
        status: j['status'] as String?,
        content: '${j['content'] ?? ''}',
        liked: _toBool(j['liked']) ?? false,
      );
}

class DynamicItem {
  final String id;
  final int authorUid;
  final String authorUsername;
  final String? authorGravatarUrl;
  final VerificationBadge authorVerificationBadge;
  final String? authorVerificationLabel;
  final String content;
  final List<String> mediaUrls;
  final String type;
  final int likes;
  final int comments;
  final bool liked;
  final DateTime? createdAt;
  final String? ipLocation;

  const DynamicItem({
    required this.id,
    this.authorUid = 0,
    this.authorUsername = '',
    this.authorGravatarUrl,
    this.authorVerificationBadge,
    this.authorVerificationLabel,
    this.content = '',
    this.mediaUrls = const [],
    this.type = 'text',
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.createdAt,
    this.ipLocation,
  });

  factory DynamicItem.fromJson(Map<String, dynamic> j) => DynamicItem(
        id: '${j['id'] ?? ''}',
        authorUid: _toInt(j['author_uid']) ?? 0,
        authorUsername: '${j['author_username'] ?? ''}',
        authorGravatarUrl: j['author_gravatar_url'] as String?,
        authorVerificationBadge: j['author_verification_badge'] as String?,
        authorVerificationLabel: j['author_verification_label'] as String?,
        content: '${j['content'] ?? ''}',
        mediaUrls: (j['media_urls'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList(),
        type: '${j['type'] ?? 'text'}',
        likes: _toInt(j['likes']) ?? 0,
        comments: _toInt(j['comments']) ?? 0,
        liked: _toBool(j['liked']) ?? false,
        createdAt: _toDate(j['created_at']),
        ipLocation: j['ip_location'] as String?,
      );
}

class Conversation {
  final String id;
  final int peerUid;
  final String peerUsername;
  final String? peerGravatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const Conversation({
    required this.id,
    this.peerUid = 0,
    this.peerUsername = '',
    this.peerGravatarUrl,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: '${j['id'] ?? ''}',
        peerUid: _toInt(j['peer_uid']) ?? 0,
        peerUsername: '${j['peer_username'] ?? ''}',
        peerGravatarUrl: j['peer_gravatar_url'] as String?,
        lastMessage: '${j['last_message'] ?? ''}',
        lastMessageAt: _toDate(j['last_message_at']),
        unreadCount: _toInt(j['unread_count']) ?? 0,
      );
}

class DirectMessage {
  final String id;
  final String conversationId;
  final int senderUid;
  final String senderUsername;
  final String content;
  final DateTime? createdAt;
  final bool read;

  const DirectMessage({
    required this.id,
    this.conversationId = '',
    this.senderUid = 0,
    this.senderUsername = '',
    this.content = '',
    this.createdAt,
    this.read = false,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> j) => DirectMessage(
        id: '${j['id'] ?? ''}',
        conversationId: '${j['conversation_id'] ?? ''}',
        senderUid: _toInt(j['sender_uid']) ?? 0,
        senderUsername: '${j['sender_username'] ?? ''}',
        content: '${j['content'] ?? ''}',
        createdAt: _toDate(j['created_at']),
        read: _toBool(j['read']) ?? false,
      );
}

class SiteNotification {
  final String id;
  final String type;
  final String title;
  final String content;
  final String? link;
  final bool read;
  final DateTime? createdAt;
  final String actorUsername;

  const SiteNotification({
    required this.id,
    this.type = '',
    this.title = '',
    this.content = '',
    this.link,
    this.read = false,
    this.createdAt,
    this.actorUsername = '',
  });

  factory SiteNotification.fromJson(Map<String, dynamic> j) => SiteNotification(
        id: '${j['id'] ?? ''}',
        type: '${j['type'] ?? ''}',
        title: '${j['title'] ?? ''}',
        content: '${j['content'] ?? ''}',
        link: j['link'] as String?,
        read: _toBool(j['read']) ?? false,
        createdAt: _toDate(j['created_at']),
        actorUsername: '${j['actor_username'] ?? ''}',
      );
}

class TicketReply {
  final String id;
  final String authorUsername;
  final String content;
  final bool isStaff;
  final DateTime? createdAt;

  const TicketReply({
    required this.id,
    this.authorUsername = '',
    this.content = '',
    this.isStaff = false,
    this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> j) => TicketReply(
        id: '${j['id'] ?? ''}',
        authorUsername: '${j['author_username'] ?? ''}',
        content: '${j['content'] ?? ''}',
        isStaff: _toBool(j['is_staff']) ?? false,
        createdAt: _toDate(j['created_at']),
      );
}

class Ticket {
  final String id;
  final String title;
  final String content;
  final String category;
  final String status;
  final String priority;
  final String creatorUsername;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TicketReply> replies;

  const Ticket({
    required this.id,
    required this.title,
    this.content = '',
    this.category = '',
    this.status = 'open',
    this.priority = 'normal',
    this.creatorUsername = '',
    this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        content: '${j['content'] ?? ''}',
        category: '${j['category'] ?? ''}',
        status: '${j['status'] ?? 'open'}',
        priority: '${j['priority'] ?? 'normal'}',
        creatorUsername: '${j['creator_username'] ?? ''}',
        createdAt: _toDate(j['created_at']),
        updatedAt: _toDate(j['updated_at']),
        replies: (j['replies'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TicketReply.fromJson)
            .toList(),
      );
}

class VoteOption {
  final String id;
  final String label;
  final String? description;
  final int voteCount;
  final double percentage;

  const VoteOption({
    required this.id,
    required this.label,
    this.description,
    this.voteCount = 0,
    this.percentage = 0,
  });

  factory VoteOption.fromJson(Map<String, dynamic> j) => VoteOption(
        id: '${j['id'] ?? ''}',
        label: '${j['label'] ?? ''}',
        description: j['description'] as String?,
        voteCount: _toInt(j['vote_count']) ?? 0,
        percentage: _toDouble(j['percentage']) ?? 0,
      );
}

class Vote {
  final String id;
  final String title;
  final String? description;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<VoteOption> options;
  final int totalVotes;
  final bool hasVoted;
  final String? votedOptionId;
  final DateTime? createdAt;

  const Vote({
    required this.id,
    required this.title,
    this.description,
    this.status = 'open',
    this.startAt,
    this.endAt,
    this.options = const [],
    this.totalVotes = 0,
    this.hasVoted = false,
    this.votedOptionId,
    this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> j) => Vote(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        description: j['description'] as String?,
        status: '${j['status'] ?? 'open'}',
        startAt: _toDate(j['start_at']),
        endAt: _toDate(j['end_at']),
        options: (j['options'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(VoteOption.fromJson)
            .toList(),
        totalVotes: _toInt(j['total_votes']) ?? 0,
        hasVoted: _toBool(j['has_voted']) ?? false,
        votedOptionId: j['voted_option_id'] as String?,
        createdAt: _toDate(j['created_at']),
      );
}

class UploadSession {
  final String uploadId;
  final String? uploadUrl;
  final List<String> chunkUrls;
  final int chunkSize;
  final int totalChunks;
  final Map<String, String> headers;

  const UploadSession({
    required this.uploadId,
    this.uploadUrl,
    this.chunkUrls = const [],
    this.chunkSize = 0,
    this.totalChunks = 0,
    this.headers = const {},
  });

  factory UploadSession.fromJson(Map<String, dynamic> j) => UploadSession(
        uploadId: '${j['upload_id'] ?? ''}',
        uploadUrl: j['upload_url'] as String?,
        chunkUrls: (j['chunk_urls'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .toList(),
        chunkSize: _toInt(j['chunk_size']) ?? 0,
        totalChunks: _toInt(j['total_chunks']) ?? 0,
        headers: (j['headers'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, '$v')),
      );
}

class SubtitleTrack {
  final String id;
  final String language;
  final String label;
  final bool isDefault;
  final String url;
  final String format;

  const SubtitleTrack({
    required this.id,
    required this.language,
    this.label = '',
    this.isDefault = false,
    required this.url,
    this.format = 'vtt',
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> j) => SubtitleTrack(
        id: '${j['id'] ?? j['language'] ?? ''}',
        language: '${j['language'] ?? ''}',
        label: '${j['label'] ?? j['language'] ?? ''}',
        isDefault: _toBool(j['default']) ?? false,
        url: '${j['url'] ?? ''}',
        format: '${j['format'] ?? 'vtt'}',
      );
}

class CollectionItem {
  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final String authorUsername;
  final int authorUid;
  final int videoCount;
  final DateTime? createdAt;
  final List<VideoItem> videos;

  const CollectionItem({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.authorUsername = '',
    this.authorUid = 0,
    this.videoCount = 0,
    this.createdAt,
    this.videos = const [],
  });

  factory CollectionItem.fromJson(Map<String, dynamic> j) => CollectionItem(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        description: j['description'] as String?,
        coverUrl: j['cover_url'] as String?,
        authorUsername: '${j['author_username'] ?? ''}',
        authorUid: _toInt(j['author_uid']) ?? 0,
        videoCount: _toInt(j['video_count']) ?? 0,
        createdAt: _toDate(j['created_at']),
        videos: (j['videos'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(VideoItem.fromJson)
            .toList(),
      );
}

// ---------- lenient primitive helpers ----------

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool? _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return null;
}

DateTime? _toDate(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

int _parseColor(dynamic v) {
  if (v is int) return 0xFF000000 | v;
  if (v is String) {
    var s = v.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    final parsed = int.tryParse(s, radix: 16);
    if (parsed != null) return parsed | 0xFF000000;
  }
  return 0xFFFFFFFF;
}
