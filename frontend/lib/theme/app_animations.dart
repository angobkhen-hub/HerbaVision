import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared timing/curves so every animation in HerbaVision feels like one system.
class HerbaMotion {
  HerbaMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 750);
  static const Duration backgroundLoop = Duration(seconds: 24);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.16, 1.0, 0.3, 1.0);
}

/// Fades, slides and (optionally) scales its child in when it first mounts.
/// Use [delay] to stagger a list of cards.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double beginScale;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = const Offset(0, 0.10),
    this.beginScale = 1.0,
    this.curve = HerbaMotion.emphasized,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = curved;
    _position = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);
    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// Counts from 0 to [value] with an ease-out curve. Updates animate smoothly
/// if the value changes later (for example after a refresh).
class AnimatedCounter extends StatelessWidget {
  final num value;
  final int decimals;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = HerbaMotion.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, current, _) {
        final text = decimals == 0
            ? current.round().toString()
            : current.toStringAsFixed(decimals);
        return Text('$prefix$text$suffix', style: style);
      },
    );
  }
}

/// Scales its child down while pressed. Uses a [Listener] so it never steals
/// taps from buttons or gestures inside the child.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool enabled;

  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
    this.enabled = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: HerbaMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Gently lifts a card when the mouse hovers over it (web/desktop).
class HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool enabled;

  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.015,
    this.enabled = true,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1.0,
        duration: HerbaMotion.fast,
        curve: HerbaMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Text with a highlight that sweeps across it. Used for the HerbaVision
/// wordmark on the splash screen.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color highlight;
  final Duration duration;

  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.highlight = Colors.white,
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style.color ?? Colors.white;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final slide = _controller.value * 3.4 - 1.7;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(slide - 1, 0),
            end: Alignment(slide + 1, 0),
            colors: [base, widget.highlight, base],
            stops: const [0.15, 0.5, 0.85],
          ).createShader(bounds),
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

/// Concentric rings that expand and fade forever. Great for "waiting" or
/// "scanning" moments.
class PulsingRings extends StatefulWidget {
  final Widget child;
  final Color color;
  final double size;
  final int ringCount;

  const PulsingRings({
    super.key,
    required this.child,
    required this.color,
    this.size = 150,
    this.ringCount = 3,
  });

  @override
  State<PulsingRings> createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<PulsingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rings = <Widget>[];
          for (var i = 0; i < widget.ringCount; i++) {
            final t = (_controller.value + i / widget.ringCount) % 1.0;
            final scale = 0.55 + t * 0.9;
            final opacity = (1 - t) * 0.32;
            rings.add(
              Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha((opacity * 255).round()),
                  ),
                ),
              ),
            );
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final ring in rings)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.08),
                    child: ring,
                  ),
                ),
              Center(child: widget.child),
            ],
          );
        },
      ),
    );
  }
}

/// Slowly drifting leaves and soft colour blobs. Purely decorative and
/// ignores pointers, so it can sit behind any screen.
class AnimatedLeafField extends StatefulWidget {
  final Color leafColor;
  final Color blobColor;
  final double intensity;
  final bool showBlobs;

  const AnimatedLeafField({
    super.key,
    this.leafColor = const Color(0xFF2F7A4F),
    this.blobColor = const Color(0xFF4FA574),
    this.intensity = 1.0,
    this.showBlobs = true,
  });

  @override
  State<AnimatedLeafField> createState() => _AnimatedLeafFieldState();
}

class _AnimatedLeafFieldState extends State<AnimatedLeafField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: HerbaMotion.backgroundLoop,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: LeafFieldPainter(
              progress: _controller.value,
              leafColor: widget.leafColor,
              blobColor: widget.blobColor,
              intensity: widget.intensity,
              showBlobs: widget.showBlobs,
            ),
          ),
        ),
      ),
    );
  }
}

/// A gradient page background with drifting leaves painted on top.
class AnimatedLeafBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final Color leafColor;
  final Color blobColor;
  final double intensity;
  final bool showBlobs;

  const AnimatedLeafBackground({
    super.key,
    required this.child,
    this.gradientColors,
    this.leafColor = const Color(0xFF2F7A4F),
    this.blobColor = const Color(0xFF4FA574),
    this.intensity = 1.0,
    this.showBlobs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ??
                  const [
                    Color(0xFFF9FBF8),
                    Color(0xFFF6F7F5),
                    Color(0xFFEEF4EF),
                  ],
            ),
          ),
        ),
        AnimatedLeafField(
          leafColor: leafColor,
          blobColor: blobColor,
          intensity: intensity,
          showBlobs: showBlobs,
        ),
        child,
      ],
    );
  }
}

/// Paints the drifting leaves + soft blobs. Deterministic (no random per frame)
/// so the field never jumps when the widget rebuilds.
class LeafFieldPainter extends CustomPainter {
  final double progress;
  final Color leafColor;
  final Color blobColor;
  final double intensity;
  final bool showBlobs;

  const LeafFieldPainter({
    required this.progress,
    required this.leafColor,
    required this.blobColor,
    this.intensity = 1.0,
    this.showBlobs = true,
  });

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final strength = intensity.clamp(0.0, 1.0);

    if (showBlobs) {
      _paintBlob(
        canvas,
        Offset(
          size.width * 0.93,
          size.height * (0.10 + 0.015 * math.sin(progress * _tau)),
        ),
        size.shortestSide * 0.46,
        blobColor.withAlpha((20 * strength).round()),
      );
      _paintBlob(
        canvas,
        Offset(
          size.width * 0.04,
          size.height * (0.92 + 0.015 * math.cos(progress * _tau)),
        ),
        size.shortestSide * 0.55,
        leafColor.withAlpha((18 * strength).round()),
      );
    }

    const count = 11;
    for (var n = 0; n < count; n++) {
      final seed = (n * 0.6180339887) % 1.0;
      final phase = seed * _tau;
      final wobble = progress * _tau + phase;

      final x = seed * size.width + math.sin(wobble) * size.width * 0.03;
      final y = ((seed * 2.7) % 1.0) * size.height +
          math.cos(wobble * 0.8) * size.height * 0.025;
      final scale = 0.55 + ((n * 37) % 11) / 13.0;
      final rotation = math.sin(wobble * 0.5) * 0.35 + seed * math.pi;
      final alpha = (30 * strength).round();

      _paintLeaf(
        canvas,
        Offset(x, y),
        24 * scale,
        50 * scale,
        rotation,
        leafColor.withAlpha(alpha),
      );
    }
  }

  void _paintBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withAlpha(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintLeaf(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    double rotation,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final path = Path()
      ..moveTo(0, -height / 2)
      ..quadraticBezierTo(width / 2, 0, 0, height / 2)
      ..quadraticBezierTo(-width / 2, 0, 0, -height / 2)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(0, -height / 2),
      Offset(0, height / 2),
      Paint()
        ..color = color
        ..strokeWidth = 1.1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LeafFieldPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.leafColor != leafColor ||
        oldDelegate.blobColor != blobColor ||
        oldDelegate.intensity != intensity ||
        oldDelegate.showBlobs != showBlobs;
  }
}

/// An animated "scanner" laid over a photo: a moving beam, a faint grid and
/// corner brackets. Used by the upload screen while the model is thinking.
class ScanningOverlay extends StatefulWidget {
  final Color color;
  final BorderRadius borderRadius;

  const ScanningOverlay({
    super.key,
    this.color = const Color(0xFF6FCB94),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ScanPainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ScanPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withAlpha(24),
    );

    final grid = Paint()
      ..color = color.withAlpha(28)
      ..strokeWidth = 1;
    const step = 34.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final beamY = size.height * (0.06 + 0.88 * progress);
    final beamRect = Rect.fromLTWH(0, beamY - 34, size.width, 68);
    canvas.drawRect(
      beamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(0),
            color.withAlpha(90),
            color.withAlpha(0),
          ],
        ).createShader(beamRect),
    );

    canvas.drawLine(
      Offset(0, beamY),
      Offset(size.width, beamY),
      Paint()
        ..color = color.withAlpha(220)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(0, beamY),
      Offset(size.width, beamY),
      Paint()
        ..color = Colors.white.withAlpha(200)
        ..strokeWidth = 1.2,
    );

    final bracket = Paint()
      ..color = color.withAlpha(230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const inset = 12.0;
    const arm = 24.0;
    final corners = <Offset>[
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final dx = i.isEven ? arm : -arm;
      final dy = i < 2 ? arm : -arm;
      canvas.drawLine(c, c + Offset(dx, 0), bracket);
      canvas.drawLine(c, c + Offset(0, dy), bracket);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
