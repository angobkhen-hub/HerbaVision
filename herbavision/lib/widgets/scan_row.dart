import 'package:flutter/material.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';

class ScanRow extends StatelessWidget {
  final HerbScan scan;

  const ScanRow({super.key, required this.scan});

  Color get _badgeBg => scan.confidence >= 90
      ? AppColors.bgSuccess
      : AppColors.bgWarning;

  Color get _badgeText => scan.confidence >= 90
      ? AppColors.textSuccess
      : AppColors.textWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco, size: 18, color: AppColors.textAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.name,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                Text(scan.latinName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${scan.confidence}% match',
              style: TextStyle(fontSize: 12, color: _badgeText),
            ),
          ),
        ],
      ),
    );
  }
}