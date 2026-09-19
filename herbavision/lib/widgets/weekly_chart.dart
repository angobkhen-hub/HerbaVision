import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WeeklyChart extends StatelessWidget {
  /// Bar heights as a percentage of [maxHeight], 0-100.
  final List<int> values;
  final double maxHeight;

  const WeeklyChart({
    super.key,
    required this.values,
    this.maxHeight = 70,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .map(
              (v) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: maxHeight * (v / 100),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}