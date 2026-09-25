import 'package:flutter/material.dart';

/// A horizontal scroller that fades its edges where more content hides
/// beyond them, so a row of chips or tiles never looks silently cut off
/// ("Hug" clipped at a card's edge). No fade when everything fits.
class EdgeFadeScroller extends StatefulWidget {
  const EdgeFadeScroller({
    super.key,
    required this.child,
    this.padding,
    this.fade = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Width of each fade, in dp.
  final double fade;

  @override
  State<EdgeFadeScroller> createState() => _EdgeFadeScrollerState();
}

class _EdgeFadeScrollerState extends State<EdgeFadeScroller> {
  final _controller = ScrollController();
  bool _before = false;
  bool _after = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_update)
      ..dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    if (!p.hasContentDimensions) return;
    final before = p.pixels > p.minScrollExtent + 0.5;
    final after = p.pixels < p.maxScrollExtent - 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _update());
        return false;
      },
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: widget.child,
      ),
    );
    if (!_before && !_after) return scroller;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In reading order: start fade, clear middle, end fade.
    final startFade = rtl ? _after : _before;
    final endFade = rtl ? _before : _after;
    return LayoutBuilder(
      builder: (context, box) {
        final f = (widget.fade / box.maxWidth).clamp(0.0, 0.3);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              startFade ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              endFade ? Colors.transparent : Colors.black,
            ],
            stops: [0, f, 1 - f, 1],
          ).createShader(rect),
          child: scroller,
        );
      },
    );
  }
}
