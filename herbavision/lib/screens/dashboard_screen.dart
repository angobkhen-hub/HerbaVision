import 'package:flutter/material.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';
import '../widgets/stat_card.dart';
import '../widgets/scan_row.dart';
import '../widgets/weekly_chart.dart';
import 'upload_screen.dart';
import 'library_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ---- Sample data — replace with real state / API results ----
  final List<HerbScan> _recentScans = [
    HerbScan(name: 'Turmeric', latinName: 'Curcuma longa', confidence: 97),
    HerbScan(name: 'Peppermint', latinName: 'Mentha piperita', confidence: 92),
    HerbScan(name: 'Ginger', latinName: 'Zingiber officinale', confidence: 78),
    HerbScan(name: 'Lemongrass', latinName: 'Cymbopogon citratus', confidence: 95),
  ];

  final List<int> _weeklyActivity = [35, 55, 40, 80, 60, 90, 70];

  void _addScan(HerbScan scan) {
    setState(() {
      _recentScans.insert(0, scan);
      if (_recentScans.length > 6) _recentScans.removeLast();
    });
  }

  Future<void> _openUploadFlow() async {
    final result = await Navigator.of(context).push<HerbScan>(
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );
    if (result != null) _addScan(result);
  }

  void _openLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(scans: _recentScans)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: isWide
              ? null
              : AppBar(
                  title: Row(
                    children: const [
                      _LogoMark(size: 22),
                      SizedBox(width: 8),
                      Text('HerbaVision',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: AppColors.surface,
                  child: _SidebarContent(
                    onLibrary: () {
                      Navigator.pop(context);
                      _openLibrary();
                    },
                    onHistory: () {
                      Navigator.pop(context);
                      _openHistory();
                    },
                    onSettings: () {
                      Navigator.pop(context);
                      _openSettings();
                    },
                    onDashboard: () => Navigator.pop(context),
                  ),
                ),
          body: SafeArea(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Persistent sidebar
                      Container(
                        width: 220,
                        decoration: const BoxDecoration(
                          border: Border(
                              right: BorderSide(color: AppColors.border)),
                        ),
                        child: _SidebarContent(
                          onLibrary: _openLibrary,
                          onHistory: _openHistory,
                          onSettings: _openSettings,
                          onDashboard: () {},
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: _DashboardBody(
                          isWide: true,
                          recentScans: _recentScans,
                          weeklyActivity: _weeklyActivity,
                          onUpload: _openUploadFlow,
                        ),
                      ),
                    ],
                  )
                : _DashboardBody(
                    isWide: false,
                    recentScans: _recentScans,
                    weeklyActivity: _weeklyActivity,
                    onUpload: _openUploadFlow,
                  ),
          ),
        );
      },
    );
  }
}

/// The small leaf logo mark next to the app name.
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.eco_outlined, color: const Color(0xFF4A7DE8), size: size);
  }
}

/// Shared sidebar/drawer content: logo header + nav items.
/// Used both as a persistent sidebar (wide screens) and inside a Drawer (narrow screens).
class _SidebarContent extends StatelessWidget {
  final VoidCallback onDashboard;
  final VoidCallback onLibrary;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  const _SidebarContent({
    required this.onDashboard,
    required this.onLibrary,
    required this.onHistory,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Row(
              children: const [
                _LogoMark(size: 24),
                SizedBox(width: 8),
                Text('HerbaVision',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home_outlined,
            label: 'Dashboard',
            selected: true,
            onTap: onDashboard,
          ),
          _DrawerItem(
            icon: Icons.menu_book_outlined,
            label: 'Herb library',
            onTap: onLibrary,
          ),
          _DrawerItem(
            icon: Icons.history,
            label: 'History',
            onTap: onHistory,
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// The scrollable main content: greeting, upload button, stats, panels.
class _DashboardBody extends StatelessWidget {
  final bool isWide;
  final List<HerbScan> recentScans;
  final List<int> weeklyActivity;
  final VoidCallback onUpload;

  const _DashboardBody({
    required this.isWide,
    required this.recentScans,
    required this.weeklyActivity,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good morning, Aiman',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          const Text(
            'Identify herbal plants by uploading a leaf photo.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Upload button
          SizedBox(
            width: isWide ? 260 : double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Upload a leaf photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stat cards
          GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 1.6 : 1.8,
            children: const [
              StatCard(label: 'Total scans', value: '1,248'),
              StatCard(label: 'Species identified', value: '312'),
              StatCard(label: 'Avg. confidence', value: '94%'),
              StatCard(label: 'Saved to library', value: '87'),
            ],
          ),
          const SizedBox(height: 20),

          // Recent scans + Weekly activity
          if (isWide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _Panel(
                      title: 'Recent scans',
                      child: Column(
                        children:
                            recentScans.map((scan) => ScanRow(scan: scan)).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _Panel(
                      title: 'Weekly scan activity',
                      child: WeeklyChart(values: weeklyActivity),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _Panel(
              title: 'Recent scans',
              child: Column(
                children:
                    recentScans.map((scan) => ScanRow(scan: scan)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Weekly scan activity',
              child: WeeklyChart(values: weeklyActivity),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.bgAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}