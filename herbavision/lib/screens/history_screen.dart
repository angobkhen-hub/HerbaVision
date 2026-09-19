import 'package:flutter/material.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';
import '../widgets/scan_row.dart';

/// Shows the user's full scan history.
/// Pass in the real list from your app state / local database / backend.
class HistoryScreen extends StatelessWidget {
  final List<HerbScan> scans;

  const HistoryScreen({super.key, required this.scans});

  Map<String, List<HerbScan>> _groupByDay() {
    final Map<String, List<HerbScan>> grouped = {};
    for (final scan in scans) {
      final label = _dayLabel(scan.scannedAt);
      grouped.putIfAbsent(label, () => []).add(scan);
    }
    return grouped;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scanDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(scanDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Scan History')),
      body: scans.isEmpty
          ? const Center(
              child: Text('No scans yet',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: entry.value
                              .map((scan) => ScanRow(scan: scan))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}