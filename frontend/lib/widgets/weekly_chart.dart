import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

/// Bar chart of scans per day for the last N days (oldest first).
/// [values] are scan counts; bars grow in and scale to the busiest day.
class WeeklyChart extends StatelessWidget {
  final List<int> values;
  final double maxHeight;

  const WeeklyChart({
    super.key,
    required this.values,
    this.maxHeight = 110,
  });

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxValue = values.fold<int>(0, math.max);

    return SizedBox(
      height: maxHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _Bar(
                index: i,
                value: values[i],
                maxValue: maxValue,
                maxHeight: maxHeight,
                label: _dayLetters[now
                        .subtract(Duration(days: values.length - 1 - i))
                        .weekday -
                    1],
                isToday: i == values.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int index;
  final int value;
  final int maxValue;
  final double maxHeight;
  final String label;
  final bool isToday;

  const _Bar({
    required this.index,
    required this.value,
    required this.maxValue,
    required this.maxHeight,
    required this.label,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value > 0 && maxValue > 0;
    final barHeight =
        hasValue ? math.max(8.0, maxHeight * value / maxValue) : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasValue)
          AnimatedCounter(
            value: value,
            duration: Duration(milliseconds: 650 + index * 70),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: barHeight),
          duration: Duration(milliseconds: 750 + index * 80),
          curve: HerbaMotion.emphasized,
          builder: (context, height, _) {
            return Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: hasValue
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: isToday
                            ? [AppColors.emerald, AppColors.lime]
                            : [AppColors.brand, AppColors.emerald],
                      )
                    : null,
                color: hasValue ? null : AppColors.border,
                borderRadius: BorderRadius.circular(6),
                boxShadow: hasValue
                    ? [
                        BoxShadow(
                          color: AppColors.emerald
                              .withAlpha(isToday ? 80 : 40),
                          blurRadius: isToday ? 14 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
