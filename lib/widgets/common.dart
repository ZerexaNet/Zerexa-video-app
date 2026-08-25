/// Shared widgets: avatars, badges, video cards, empty/error states.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../theme/app_themes.dart';

/// Circular avatar with gravatar image and initial-letter fallback.
class ZxAvatar extends StatelessWidget {
  const ZxAvatar({super.key, this.url, this.name = '', this.size = 40, this.onTap});

  final String? url;
  final String name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthStore>().api;
    final resolved = url == null || url!.isEmpty ? null : api.resolveAsset(url);
    Widget avatar;
    if (resolved != null && resolved.startsWith('http')) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundImage: CachedNetworkImageProvider(resolved),
        onForegroundImageError: (_, _) {},
        child: _fallbackText(context),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: context.zx.accentFor(name.hashCode),
        child: _fallbackText(context),
      );
    }
    if (onTap == null) return avatar;
    return InkWell(onTap: onTap, customBorder: const CircleBorder(), child: avatar);
  }

  Widget _fallbackText(BuildContext context) => Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// Yellow / green verification badge shown next to author names.
class ZxBadge extends StatelessWidget {
  const ZxBadge({super.key, this.badge, this.label});

  final VerificationBadge badge;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (badge != 'yellow' && badge != 'green') return const SizedBox.shrink();
    final color = badge == 'yellow' ? const Color(0xFFF5A623) : const Color(0xFF2E9E6B);
    final icon = badge == 'yellow' ? Icons.star_rounded : Icons.verified_rounded;
    if (label == null || label!.isEmpty) {
      return Icon(icon, size: 15, color: color, semanticLabel: 'verified');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label!,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Author row: avatar + name + verification badge.
class ZxAuthor extends StatelessWidget {
  const ZxAuthor({
    super.key,
    required this.username,
    this.uid,
    this.gravatar,
    this.badge,
    this.badgeLabel,
    this.size = 20,
    this.onTap,
  });

  final String username;
  final int? uid;
  final String? gravatar;
  final VerificationBadge badge;
  final String? badgeLabel;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ZxAvatar(url: gravatar, name: username, size: size),
      const SizedBox(width: 6),
      Flexible(
        child: GestureDetector(
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(
                username.isEmpty ? '匿名' : username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size * .55, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            ZxBadge(badge: badge, label: badgeLabel),
          ]),
        ),
      ),
    ]);
  }
}

/// Video thumbnail with duration placeholder and view count overlay.
class ZxVideoCard extends StatelessWidget {
  const ZxVideoCard({super.key, required this.video, this.onTap});

  final VideoItem video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<AuthStore>().api;
    final cover = api.resolveAsset(video.displayCover);
    final metro = context.read<ThemeStore>().mode == AppThemeMode.metro;

    if (metro) {
      // Metro: solid colour block with hard edges.
      final accent = context.zx.accentFor(video.id.hashCode);
      return InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: accent,
              child: cover.isEmpty
                  ? Center(
                      child: Icon(Icons.play_arrow_rounded,
                          size: 44, color: Colors.white.withValues(alpha: .9)))
                  : Image(
                      image: CachedNetworkImageProvider(cover),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(Icons.play_arrow_rounded,
                            size: 44, color: Colors.white.withValues(alpha: .9)),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              '${formatCount(video.views)} 次观看 · ${video.authorUsername}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.zx.cardRadius * .6),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              if (cover.isEmpty)
                Container(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.movie_outlined,
                      size: 36, color: scheme.onSurfaceVariant),
                )
              else
                Image(
                  image: CachedNetworkImageProvider(cover),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.movie_outlined,
                        size: 36, color: scheme.onSurfaceVariant),
                  ),
                ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${formatCount(video.views)} 播放',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.3,
            fontWeight: context.zx.boldTitles ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${video.authorUsername.isEmpty ? '匿名' : video.authorUsername} · ${formatRelative(video.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// Responsive video grid that adapts column count to screen width.
class ZxVideoGrid extends StatelessWidget {
  const ZxVideoGrid({super.key, required this.videos, this.onOpen});

  final List<VideoItem> videos;
  final void Function(VideoItem video)? onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width > 1600
          ? 6
          : width > 1250
              ? 5
              : width > 950
                  ? 4
                  : width > 680
                      ? 3
                      : 2;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
          childAspectRatio: .78,
        ),
        itemCount: videos.length,
        itemBuilder: (context, i) =>
            ZxVideoCard(video: videos[i], onTap: () => onOpen?.call(videos[i])),
      );
    });
  }
}

class ZxLoadingGrid extends StatelessWidget {
  const ZxLoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width > 950 ? 4 : width > 680 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
          childAspectRatio: .78,
        ),
        itemCount: 12,
        itemBuilder: (context, i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
                height: 12,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest),
            const SizedBox(height: 6),
            Container(
                height: 10,
                width: 120,
                color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ],
        ),
      );
    });
  }
}

class ZxEmpty extends StatelessWidget {
  const ZxEmpty({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: .5)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

class ZxError extends StatelessWidget {
  const ZxError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 52, color: scheme.error),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Section title with optional trailing action.
class ZxSectionTitle extends StatelessWidget {
  const ZxSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final themeStore = context.read<ThemeStore>();
    final metro = themeStore.mode == AppThemeMode.metro;
    final text = metro ? title.toUpperCase() : title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 10),
      child: Row(children: [
        if (metro) ...[
          Container(width: 4, height: 18, color: context.zx.accentFor(0)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: context.zx.boldTitles ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: metro ? 1.0 : 0,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// App logo drawn from the bundled SVG asset (no emoji anywhere).
class ZxLogo extends StatelessWidget {
  const ZxLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      'assets/logo.svg',
      height: height,
      colorFilter: dark
          ? const ColorFilter.mode(Color(0xFFE7ECF5), BlendMode.srcIn)
          : null,
    );
  }
}

/// Small toast helper.
void zxToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
