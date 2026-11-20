import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_state.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/herba_ui.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// How long the animated splash stays up at minimum. This gives the opening
/// animation time to breathe even when the saved session check is instant.
const Duration _kMinimumSplash = Duration(milliseconds: 2200);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _minimumTimeElapsed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthState>().checkExistingSession();
    });
    _timer = Timer(_kMinimumSplash, () {
      if (mounted) setState(() => _minimumTimeElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        final stillChecking =
            authState.status == AuthStatus.checking || !_minimumTimeElapsed;

        final Widget next;
        if (stillChecking) {
          next = const _AnimatedSplash();
        } else if (authState.status == AuthStatus.loggedOut) {
          next = const LoginScreen();
        } else {
          next = const DashboardScreen();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          switchInCurve: HerbaMotion.emphasized,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(stillChecking ? 'splash' : authState.status),
            child: next,
          ),
        );
      },
    );
  }
}

class _AnimatedSplash extends StatelessWidget {
  const _AnimatedSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: HerbaBackdrop(
        intensity: 1.5,
        child: SafeArea(
          child: Stack(
            children: [
              // Slow scanning line across the whole screen.
              const Positioned.fill(
                child: IgnorePointer(child: _SplashScanLine()),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeSlideIn(
                        offset: const Offset(0, -0.4),
                        child: MicroLabel(
                          'Botanical intelligence engine',
                          color: AppColors.lime,
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeSlideIn(
                        beginScale: 0.82,
                        duration: const Duration(milliseconds: 900),
                        child: ScanReticle(
                          size: 240,
                          color: AppColors.emerald,
                          child: HerbaLogo(size: 92),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 200),
                        offset: Offset(0, 0.24),
                        child: GradientText(
                          'HerbaVision',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.6,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFD8FF7A),
                              Color(0xFF2EE59D),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 330),
                        child: Text(
                          'See the plant. Know the herb.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 15,
                            height: 1.4,
                            letterSpacing: 0.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 460),
                        offset: Offset(0, 0.3),
                        child: _SplashLoader(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: Center(
                    child: Text(
                      'SECURE LEAF SCAN  ·  v1.0',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9.5,
                        letterSpacing: 2.2,
                        color: AppColors.textMuted.withAlpha(170),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A faint lime line that sweeps down the splash screen.
class _SplashScanLine extends StatefulWidget {
  const _SplashScanLine();

  @override
  State<_SplashScanLine> createState() => _SplashScanLineState();
}

class _SplashScanLineState extends State<_SplashScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final y = _controller.value * constraints.maxHeight;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: y,
                  child: Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.emerald.withAlpha(0),
                          AppColors.emerald.withAlpha(80),
                          AppColors.lime.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return SizedBox(
              width: 168,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      children: [
                        Container(
                          height: 5,
                          color: Colors.white.withAlpha(18),
                        ),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withAlpha(120),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MicroLabel(
                    'Initialising vision core',
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
