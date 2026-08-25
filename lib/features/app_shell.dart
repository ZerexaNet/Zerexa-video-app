/// Adaptive navigation shell.
///
/// Narrow screens get a Material [NavigationBar] at the bottom; wide screens
/// (desktop / tablets) get a [NavigationRail] on the left side with a
/// scrollable content area. Metro theme renders nav labels uppercase.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../stores/app_stores.dart';
import '../theme/app_themes.dart';
import '../widgets/common.dart';
import 'auth_view.dart';
import 'discover_view.dart';
import 'dynamics_view.dart';
import 'home_view.dart';
import 'messages_view.dart';
import 'mine_view.dart';
import 'watch_view.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeView(),
    DiscoverView(),
    DynamicsView(),
    MessagesView(),
    MineView(),
  ];

  static const _labels = ['首页', '发现', '动态', '消息', '我的'];

  static const _icons = <IconData>[
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.bolt_outlined,
    Icons.forum_outlined,
    Icons.person_outline,
  ];

  static const _selectedIcons = <IconData>[
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.bolt_rounded,
    Icons.forum_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final metro = context.read<ThemeStore>().mode == AppThemeMode.metro;
    final auth = context.watch<AuthStore>();

    final body = IndexedStack(index: _index, children: _screens);

    if (!wide) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => _select(i, auth),
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(
                icon: _navIcon(context, i, false, auth),
                selectedIcon: _navIcon(context, i, true, auth),
                label: metro ? _labels[i].toUpperCase() : _labels[i],
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => _select(i, auth),
          extended: MediaQuery.sizeOf(context).width >= 1200,
          minExtendedWidth: 190,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [const ZxLogo(height: 26)]),
          ),
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationRailDestination(
                icon: _navIcon(context, i, false, auth),
                selectedIcon: _navIcon(context, i, true, auth),
                label: Text(metro ? _labels[i].toUpperCase() : _labels[i]),
              ),
          ],
        ),
        VerticalDivider(
          thickness: context.zx.dividerWeight,
          width: context.zx.dividerWeight + 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(child: body),
      ]),
    );
  }

  void _select(int i, AuthStore auth) {
    if ((i == 2 || i == 3) && !auth.isAuthed) {
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AuthScreen(),
      ));
      return;
    }
    setState(() => _index = i);
  }

  Widget _navIcon(BuildContext context, int i, bool selected, AuthStore auth) {
    final icon = Icon(selected ? _selectedIcons[i] : _icons[i]);
    if (i == 3 && auth.isAuthed) {
      final unread = context.watch<UnreadBadge>();
      if (unread.count > 0) return _BadgedIcon(icon: icon, count: unread.count);
    }
    return icon;
  }
}

/// Small helper widget: icon wrapped in a red count badge.
class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      icon,
      Positioned(
        right: -6,
        top: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(minWidth: 14),
          child: Text(
            count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Unread message/notifications badge shared across tabs. Provided in the
/// root [MultiProvider] (see [main]) so the shell can listen to it.
class UnreadBadge extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  set count(int v) {
    if (v == _count) return;
    _count = v;
    notifyListeners();
  }
}

/// Convenience: opens [VideoItem] detail (used by cards across the app).
void openVideo(BuildContext context, VideoItem video) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => WatchView(videoId: video.id),
  ));
}
