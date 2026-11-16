import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  /// Small muted text shown after the value, e.g. "of 6".
  final String? suffix;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withAlpha(AppColors.isDark ? 26 : 18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brand.withAlpha(60)),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.textAccent),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppColors.textPrimary,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 6),
                Text(
                  suffix!,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}