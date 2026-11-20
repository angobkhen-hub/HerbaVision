import 'package:flutter/material.dart';

import 'app_animations.dart';

/// A soft fade + rise transition used for every screen push in HerbaVision.
/// Keeping it in one helper means the whole app moves the same way.
Route<T> herbaRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _buildFadeSlide(animation, child),
  );
}

Widget _buildFadeSlide(Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: HerbaMotion.emphasized,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// Applies the same motion to any plain [MaterialPageRoute] (dialogs and
/// screens that are pushed without [herbaRoute]).
class HerbaPageTransitionsBuilder extends PageTransitionsBuilder {
  const HerbaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildFadeSlide(animation, child);
  }
}
