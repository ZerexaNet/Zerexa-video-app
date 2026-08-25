/// Native scrolling-danmaku overlay for the video player.
///
/// The overlay listens to a [ValueListenable] holding the current playback
/// position (seconds) and spawns right-to-left scrolling comments at their
/// timestamps. Lanes are allocated top-down; overflow comments are dropped.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.items,
    required this.position,
    this.enabled = true,
    this.fontSize = 16,
    this.opacity = 1,
    this.duration = const Duration(seconds: 8),
  });

  final List<DanmakuItem> items;
  final ValueListenable<double> position;
  final bool enabled;
  final double fontSize;
  final double opacity;
  final Duration duration;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _ActiveDanmaku {
  _ActiveDanmaku({
    required this.item,
    required this.controller,
    required this.track,
    required this.textWidth,
  });

  final DanmakuItem item;
  final AnimationController controller;
  final int track;
  final double textWidth;
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with TickerProviderStateMixin {
  final _active = <_ActiveDanmaku>[];
  final List<bool> _tracks = List.filled(12, false);
  int _cursor = 0;
  double _lastTime = -1;
  List<DanmakuItem> _sorted = const [];

  @override
  void initState() {
    super.initState();
    _sortItems();
    widget.position.addListener(_onTick);
  }

  @override
  void didUpdateWidget(DanmakuOverlay old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _sortItems();
    }
    if (old.position != widget.position) {
      old.position.removeListener(_onTick);
      widget.position.addListener(_onTick);
    }
    if (old.enabled && !widget.enabled) {
      _clearAll();
    }
  }

  void _sortItems() {
    _sorted = List.of(widget.items)..sort((a, b) => a.time.compareTo(b.time));
    // Reset cursor to just before current position so seeking works.
    _cursor = 0;
    _lastTime = -1;
  }

  void _onTick() {
    if (!widget.enabled || !mounted) return;
    final now = widget.position.value;
    if (now < _lastTime) {
      // Seek backwards: rescan.
      _cursor = 0;
    }
    _lastTime = now;
    while (_cursor < _sorted.length && _sorted[_cursor].time <= now) {
      final item = _sorted[_cursor];
      if (now - item.time < 1.2) _spawn(item);
      _cursor++;
    }
  }

  void _spawn(DanmakuItem item) {
    if (_active.length >= 24) return;
    int track = -1;
    for (var i = 0; i < _tracks.length; i++) {
      if (!_tracks[i]) {
        track = i;
        break;
      }
    }
    if (track < 0) return;

    final tp = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          fontSize: widget.fontSize,
          color: Color(item.color),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final controller = AnimationController(vsync: this, duration: widget.duration);
    final active = _ActiveDanmaku(
      item: item,
      controller: controller,
      track: track,
      textWidth: tp.width,
    );
    _tracks[track] = true;
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _active.remove(active);
            if (active.track >= 0 && active.track < _tracks.length) {
              _tracks[active.track] = false;
            }
          });
          controller.dispose();
        } else {
          controller.dispose();
        }
      }
    });
    setState(() => _active.add(active));
    controller.forward();
  }

  void _clearAll() {
    for (final a in _active) {
      a.controller.stop();
      a.controller.dispose();
    }
    _active.clear();
    _tracks.fillRange(0, _tracks.length, false);
  }

  @override
  void dispose() {
    widget.position.removeListener(_onTick);
    _clearAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _active.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(builder: (context, constraints) {
          final laneHeight = widget.fontSize + 14;
          final width = constraints.maxWidth;
          return Stack(children: [
            for (final a in _active)
              AnimatedBuilder(
                animation: a.controller,
                builder: (context, _) {
                  final t = a.controller.value;
                  final x = width - (width + a.textWidth + 24) * t;
                  return Positioned(
                    left: x,
                    top: 8.0 + a.track * laneHeight,
                    child: Opacity(
                      opacity: widget.opacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          a.item.text,
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            color: Color(a.item.color),
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ]);
        }),
      ),
    );
  }
}
