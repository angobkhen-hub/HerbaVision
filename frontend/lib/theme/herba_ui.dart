import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'app_colors.dart';

/// ---------------------------------------------------------------------------
/// HerbaVision design system ("botanical intelligence lab").
///
/// Shared visual building blocks used across the app: animated aurora
/// backdrop, glass panels, neon buttons, mono micro-labels, scan reticles and
/// gradient wordmarks. Purely presentational — no app logic lives here.
/// ---------------------------------------------------------------------------

/// Animated page backdrop: deep gradient, drifting aurora orbs, a faint
/// blueprint dot-grid and a few slow-floating leaves.
class HerbaBackdrop extends StatefulWidget {
  final Widget child;
  final bool showGrid;
  final bool showLeaves;
  final double intensity;

  const HerbaBackdrop({
    super.key,
    required this.child,
    this.showGrid = true,
    this.showLeaves = true,
    this.intensity = 1.0,
  });

  @override
  State<HerbaBackdrop> createState() => _HerbaBackdropState();
}

class _HerbaBackdropState extends State<HerbaBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bg, AppColors.bgBottom],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value * math.pi * 2;
          final x1 = math.sin(t) * 0.85;
          final y1 = math.cos(t * 0.8) * 0.75;
          final x2 = math.cos(t * 0.7 + 1.4) * 0.9;
          final y2 = math.sin(t * 0.6 + 2.1) * 0.6;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.showGrid)
                CustomPaint(
                  painter: _DotGridPainter(dark: dark),
                ),
              Align(
                alignment: Alignment(x1, y1),
                child: _Orb(
                  size: 620,
                  color: dark
                      ? const Color(0xFF1F8A52)
                      : const Color(0xFF8BD9A4),
                  opacity: (dark ? 0.20 : 0.30) * widget.intensity,
                ),
              ),
              Align(
                alignment: Alignment(x2, y2),
                child: _Orb(
                  size: 480,
                  color: dark
                      ? const Color(0xFF7FE03C)
                      : const Color(0xFFC6E87A),
                  opacity: (dark ? 0.10 : 0.22) * widget.intensity,
                ),
              ),
              Align(
                alignment: Alignment(0, 1.15),
                child: _Orb(
                  size: 700,
                  color: dark
                      ? const Color(0xFF0F5A6B)
                      : const Color(0xFFBFE6DA),
                  opacity: (dark ? 0.16 : 0.28) * widget.intensity,
                ),
              ),
              if (widget.showLeaves)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedLeafField(
                      leafColor: dark
                          ? const Color(0xFFB7F94B)
                          : const Color(0xFF2F7A4F),
                      blobColor: const Color(0xFF2EE59D),
                      intensity: (dark ? 0.35 : 0.5) * widget.intensity,
                      showBlobs: false,
                    ),
                  ),
                ),
              child!,
            ],
          );
        },
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Orb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final a = (opacity * 255).round();
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withAlpha(a), color.withAlpha(0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final bool dark;
  const _DotGridPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withAlpha(dark ? 12 : 9)
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// Frosted glass container with a hairline border, soft depth shadow and an
/// optional accent glow. Used for every card / panel in the app.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool glow;
  final VoidCallback? onTap;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.tint,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppColors.glassGradient;
    final colors = tint == null
        ? base.colors
        : [
            Color.alphaBlend(
                tint!.withAlpha(AppColors.isDark ? 16 : 12), base.colors.first),
            base.colors.last,
          ];

    Widget panel = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          if (glow)
            BoxShadow(
              color: (tint ?? AppColors.brand)
                  .withAlpha(AppColors.isDark ? 30 : 22),
              blurRadius: 50,
              spreadRadius: -10,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.glassHighlight),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap != null) {
      panel = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: panel,
        ),
      );
    }

    return panel;
  }
}

/// Electric lime pill button with a soft glow.
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool loading;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    final button = Container(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.brandGradient,
        color: disabled ? AppColors.border : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: (AppColors.isDark
                          ? AppColors.emerald
                          : AppColors.brand)
                      .withAlpha(60),
                  blurRadius: 26,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.onBrand,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: AppColors.onBrand),
                if (loading || icon != null) const SizedBox(width: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: AppColors.onBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return PressableScale(
      enabled: !disabled,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Small uppercase technical label in JetBrains Mono, with a glowing dot.
class MicroLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;
  final bool dot;

  const MicroLabel(
    this.text, {
    super.key,
    this.color,
    this.trailing,
    this.dot = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: c.withAlpha(160), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
            color: c,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

/// Rounded status chip with a tinted background and mono text.
class HerbaPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  const HerbaPill(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.emerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withAlpha(AppColors.isDark ? 22 : 18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withAlpha(AppColors.isDark ? 70 : 55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.withAlpha(150), blurRadius: 5)],
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// The HerbaVision mark: lime-to-mint gradient tile with a leaf glyph.
class HerbaLogo extends StatelessWidget {
  final double size;
  final bool glow;

  const HerbaLogo({super.key, this.size = 34, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.emerald.withAlpha(70),
                  blurRadius: size * 0.55,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.eco_rounded,
        size: size * 0.6,
        color: AppColors.onBrand,
      ),
    );
  }
}

/// Animated circular scan reticle: dashed ring, rotating sweep, crosshairs.
class ScanReticle extends StatefulWidget {
  final double size;
  final Color? color;
  final Widget? child;

  const ScanReticle({super.key, this.size = 220, this.color, this.child});

  @override
  State<ScanReticle> createState() => _ScanReticleState();
}

class _ScanReticleState extends State<ScanReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.emerald;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _ReticlePainter(
            progress: _controller.value,
            color: color,
          ),
          child: child,
        ),
        child: Center(
          child: widget.child ??
              Container(
                width: widget.size * 0.34,
                height: widget.size * 0.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(90),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: widget.size * 0.16,
                  color: AppColors.onBrand,
                ),
              ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ReticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final angle = progress * math.pi * 2;

    final ring = Paint()
      ..color = color.withAlpha(90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Dashed outer ring.
    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r * 0.92));
    for (final metric in outer.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), ring);
        d += 10;
      }
    }

    // Inner ring.
    canvas.drawCircle(center, r * 0.62, ring..color = color.withAlpha(45));

    // Crosshair ticks.
    final tick = Paint()
      ..color = color.withAlpha(140)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = angle + i * math.pi / 2;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (r * 0.78);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (r * 0.98);
      canvas.drawLine(p1, p2, tick);
    }

    // Rotating sweep.
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [color.withAlpha(0), color.withAlpha(50)],
        stops: const [0.72, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: r));

    canvas.drawCircle(center, r * 0.9, sweep);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Text filled with the brand gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient? gradient;
  final TextAlign textAlign;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => (gradient ?? AppColors.brandGradient)
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
