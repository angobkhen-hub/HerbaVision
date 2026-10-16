import 'package:flutter/material.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';

const _herbalSpecies = [
  'blumea balsamifera',
  'annona muricata',
  'hyptis capitata',
];
const _herbalNames = ['sambong', 'guyabano', 'sawansawan'];

/// True when the scan is one of the medicinal herbs the app recognizes.
bool isHerbalScan(HerbScan scan) {
  final latin = scan.latinName.toLowerCase();
  final name = scan.name.toLowerCase();
  return _herbalSpecies.any(latin.contains) || _herbalNames.any(name.contains);
}

class ScanRow extends StatelessWidget {
  final HerbScan scan;

  /// Small muted text under the plant name, e.g. the time of the scan.
  final String? meta;

  /// Makes the row tappable when provided.
  final VoidCallback? onTap;

  /// Draws the line under the row. Turn off for the last row in a card.
  final bool showDivider;

  const ScanRow({
    super.key,
    required this.scan,
    this.meta,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final herbal = isHerbalScan(scan);
    final iconBg = herbal ? AppColors.bgSuccess : AppColors.bgWarning;
    final iconFg = herbal ? AppColors.textSuccess : AppColors.textWarning;
    final highConfidence = scan.confidence >= 90;
    final barColor = highConfidence ? AppColors.brand : AppColors.textWarning;

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(herbal ? Icons.eco : Icons.local_florist_outlined,
                size: 20, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                if (scan.latinName.isNotEmpty)
                  Text(
                    scan.latinName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary),
                  ),
                if (meta != null)
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              herbal ? 'Herbal' : 'Non-herbal',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: iconFg),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${scan.confidence}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (scan.confidence.clamp(0, 100)) / 100,
                    minHeight: 5,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}