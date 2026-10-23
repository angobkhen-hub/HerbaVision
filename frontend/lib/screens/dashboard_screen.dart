// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';
import '../widgets/scan_row.dart';
import '../widgets/weekly_chart.dart';
import '../services/auth_state.dart';
import '../services/api_service.dart';
import 'upload_screen.dart';
import 'library_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'report_form_screen.dart';

/// Screens at least this wide get the sidebar ("web") layout.
/// Narrower screens get the mobile layout with a drawer.
const double _kWideBreakpoint = 900;

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = false;
  String? _error;
  String? _loadedForToken; // guards against duplicate/stale fetches

  int _totalScans = 0;
  int _speciesIdentified = 0;
  double _avgConfidence = 0;
  int _savedToLibrary = 0;
  List<HerbScan> _recentScans = [];
  List<int> _weeklyActivity = List.filled(7, 0);

  // ---------------------------------------------------------------------
  // LOGIC (unchanged)
  // ---------------------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.watch<AuthState>();
    final currentToken = authState.isLoggedIn ? authState.token : null;

    // Re-fetch whenever the effective identity changes: login, logout,
    // switching to guest, or the very first build.
    if (_loadedForToken != currentToken) {
      _loadedForToken = currentToken;
      _loadData(authState);
    }
  }

  Future<void> _loadData(AuthState authState) async {
    if (!authState.isLoggedIn || authState.token == null) {
      // Guest (or logged out): nothing to fetch, nothing to fake.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _totalScans = 0;
        _speciesIdentified = 0;
        _avgConfidence = 0;
        _savedToLibrary = 0;
        _recentScans = [];
        _weeklyActivity = List.filled(7, 0);
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = authState.token!;
      final results = await Future.wait([
        ApiService.getStats(token),
        ApiService.getScans(token),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final scansJson =
          (results[1] as List<dynamic>).cast<Map<String, dynamic>>();

      final recent = scansJson.take(6).map((s) {
        final confidence = (s['confidence'] as num).round();
        return HerbScan(
          name: s['plant_name'] as String,
          latinName: (s['latin_name'] as String?) ?? '',
          confidence: confidence,
        );
      }).toList();

      final weekly = _computeWeeklyActivity(scansJson);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _totalScans = stats['total_scans'] as int;
        _speciesIdentified = stats['species_identified'] as int;
        _avgConfidence = (stats['avg_confidence'] as num).toDouble();
        _savedToLibrary = stats['saved_to_library'] as int;
        _recentScans = recent;
        _weeklyActivity = weekly;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load your dashboard.";
      });
    }
  }

  /// Counts scans per calendar day for the last 7 days, using each
  /// scan's real created_at timestamp from the database.
  List<int> _computeWeeklyActivity(List<Map<String, dynamic>> scansJson) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = List.filled(7, 0);

    for (final s in scansJson) {
      final createdRaw = s['created_at'] as String?;
      if (createdRaw == null) continue;
      final created = DateTime.parse(createdRaw).toLocal();
      final day = DateTime(created.year, created.month, created.day);
      final idx = days.indexWhere((d) => d == day);
      if (idx != -1) counts[idx]++;
    }
    return counts;
  }

  Future<void> _refresh() async {
    await _loadData(context.read<AuthState>());
  }

  Future<void> _openUploadFlow() async {
    final result = await Navigator.of(context).push<HerbScan>(
      MaterialPageRoute(builder: (_) => UploadScreen()),
    );
    if (result == null || !mounted) return;

    final authState = context.read<AuthState>();
    String? note;

    if (authState.isLoggedIn && authState.token != null) {
      try {
        await ApiService.createScan(
          token: authState.token!,
          plantName: result.name,
          latinName: result.latinName,
          confidence: result.confidence.toDouble(),
        );
        note = 'Saved to your scan history.';
      } catch (_) {
        note = "Identified, but the scan couldn't be saved. Please try again.";
      }
      if (!mounted) return;
      // Re-fetch from the DB so totals, species count, etc. stay accurate.
      await _loadData(authState);
    } else {
      note = 'Sign up to save your scan history.';
    }

    if (!mounted) return;
    await _showResultDialog(result, note);
  }

  Future<void> _showResultDialog(HerbScan scan, String? note) async {
    // Look up the herb's stored information (leaf_items table). If it can't be
    // loaded, the dialog still shows the identification result.
    final info = await ApiService.getHerbInfo(scan.latinName);
    if (!mounted) return;

    Widget section(String title, String? text) {
      if (text == null || text.trim().isEmpty) return SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(scan.name),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scan.latinName.isNotEmpty)
                  Text(
                    scan.latinName,
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                SizedBox(height: 8),
                Text('Confidence: ${scan.confidence}%'),
                if (note != null) ...[
                  SizedBox(height: 8),
                  Text(
                    note,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
                if (info == null) ...[
                  SizedBox(height: 14),
                  Text(
                    'More information about this plant is coming soon.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
                section('About', info?['description'] as String?),
                section('Benefits', info?['benefits'] as String?),
                section(
                    'Traditional uses', info?['traditional_uses'] as String?),
                section('Risks', info?['risks'] as String?),
                section('Precautions', info?['precautions'] as String?),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LibraryScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(scans: _recentScans)),
    );
  }

  void _openReportForm() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportFormScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen()),
    );
  }

  // ---------------------------------------------------------------------
  // DISPLAY: picks the layout from the available width
  // ---------------------------------------------------------------------

  Widget _buildBody({required bool isWide}) {
    return _DashboardBody(
      isWide: isWide,
      loading: _loading,
      error: _error,
      totalScans: _totalScans,
      speciesIdentified: _speciesIdentified,
      avgConfidence: _avgConfidence,
      savedToLibrary: _savedToLibrary,
      recentScans: _recentScans,
      weeklyActivity: _weeklyActivity,
      onUpload: _openUploadFlow,
      onRefresh: _refresh,
      onViewAll: _openHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _kWideBreakpoint;

          // WEB: permanent sidebar + wide content area.
          if (isWide) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 290,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.surface, AppColors.bgBottom],
                      ),
                      border:
                          Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: _SidebarContent(
                      onDashboard: () {},
                      onLibrary: _openLibrary,
                      onHistory: _openHistory,
                      onReport: _openReportForm,
                      onSettings: _openSettings,
                    ),
                  ),
                  Expanded(child: SafeArea(child: _buildBody(isWide: true))),
                ],
              ),
            );
          }

          // MOBILE: app bar + drawer + single scrolling column.
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  _LogoMark(size: 28),
                  SizedBox(width: 10),
                  Text(
                    'HerbaVision',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            drawer: Drawer(
              backgroundColor: AppColors.surface,
              child: _SidebarContent(
                onDashboard: () => Navigator.pop(context),
                onLibrary: () {
                  Navigator.pop(context);
                  _openLibrary();
                },
                onHistory: () {
                  Navigator.pop(context);
                  _openHistory();
                },
                onReport: () {
                  Navigator.pop(context);
                  _openReportForm();
                },
                onSettings: () {
                  Navigator.pop(context);
                  _openSettings();
                },
              ),
            ),
            body: SafeArea(child: _buildBody(isWide: false)),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display widgets
// ---------------------------------------------------------------------------

/// Page background: soft gradient + faint decorative blobs and a big leaf.
class _AppBackground extends StatelessWidget {
  final Widget child;
  const _AppBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTop, AppColors.bg, AppColors.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: IgnorePointer(
              child: _Blob(size: 300, color: AppColors.brand.withOpacity(0.08)),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: IgnorePointer(
              child: _Blob(
                  size: 340, color: AppColors.brandLight.withOpacity(0.10)),
            ),
          ),
          Positioned(
            right: 36,
            bottom: 28,
            child: IgnorePointer(
              child: Icon(Icons.eco,
                  size: 190, color: AppColors.brand.withOpacity(0.05)),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandLight, AppColors.brandDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(Icons.eco, size: size * 0.6, color: AppColors.onBrand),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final VoidCallback onDashboard;
  final VoidCallback onLibrary;
  final VoidCallback onHistory;
  final VoidCallback onReport;
  final VoidCallback onSettings;

  const _SidebarContent({
    required this.onDashboard,
    required this.onLibrary,
    required this.onHistory,
    required this.onReport,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final name = authState.userName ?? 'Guest';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Row(
              children: [
                _LogoMark(size: 32),
                SizedBox(width: 10),
                Text(
                  'HerbaVision',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
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
            icon: Icons.report_outlined,
            label: 'Report form',
            onTap: onReport,
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
          Spacer(),
          Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brand,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppColors.onBrand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        authState.isGuest ? 'Browsing as guest' : 'Signed in',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable main content: hero banner, stats, panels.
class _DashboardBody extends StatelessWidget {
  final bool isWide;
  final bool loading;
  final String? error;
  final int totalScans;
  final int speciesIdentified;
  final double avgConfidence;
  final int savedToLibrary;
  final List<HerbScan> recentScans;
  final List<int> weeklyActivity;
  final VoidCallback onUpload;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAll;

  const _DashboardBody({
    required this.isWide,
    required this.loading,
    required this.error,
    required this.totalScans,
    required this.speciesIdentified,
    required this.avgConfidence,
    required this.savedToLibrary,
    required this.recentScans,
    required this.weeklyActivity,
    required this.onUpload,
    required this.onRefresh,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final hasAnyScans = totalScans > 0;
    final weekTotal = weeklyActivity.fold<int>(0, (a, b) => a + b);
    final name = authState.userName ?? 'there';

    final uploadButton = ElevatedButton.icon(
      onPressed: onUpload,
      icon: Icon(Icons.upload_outlined, size: 20),
      label: Text('Upload a leaf photo'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandDark,
        elevation: 0,
        minimumSize: Size(0, 52),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
        ),
      ),
    );

    final stats = <Widget>[
      _StatTile(
        label: 'Total scans',
        value: loading ? '—' : '$totalScans',
        icon: Icons.document_scanner_outlined,
        color: AppColors.brand,
      ),
      _StatTile(
        label: 'Species identified',
        value: loading ? '—' : '$speciesIdentified',
        icon: Icons.spa_outlined,
        color: AppColors.accentBlue,
      ),
      _StatTile(
        label: 'Avg. confidence',
        value:
            loading ? '—' : (hasAnyScans ? '${avgConfidence.round()}%' : '—'),
        icon: Icons.verified_outlined,
        color: AppColors.accentAmber,
      ),
      _StatTile(
        label: 'Saved to library',
        value: loading ? '—' : '$savedToLibrary',
        icon: Icons.bookmark_border,
        color: AppColors.accentPurple,
      ),
    ];

    final recentPanel = _Panel(
      title: 'Recent scans',
      trailing: recentScans.isEmpty
          ? null
          : TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                visualDensity: VisualDensity.compact,
              ),
              child: Text('View all'),
            ),
      child: _RecentScansContent(
        loading: loading,
        isGuest: authState.isGuest,
        scans: recentScans,
      ),
    );

    final weeklyPanel = _Panel(
      title: 'Weekly scan activity',
      trailing: loading || weekTotal == 0
          ? null
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$weekTotal this week',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandDark,
                ),
              ),
            ),
      child: loading
          ? _InlineLoading()
          : weekTotal == 0
              ? _EmptyNote('No scans in the last 7 days.')
              : WeeklyChart(values: weeklyActivity),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroBanner(
                  isWide: isWide,
                  title: '${_greeting()}, $name',
                  subtitle: authState.isGuest
                      ? "You're browsing as a guest. Sign up to save your scan history."
                      : 'Identify herbal plants by uploading a leaf photo.',
                  action: uploadButton,
                  onRefresh: loading ? null : () => onRefresh(),
                ),
                SizedBox(height: isWide ? 28 : 20),

                if (error != null)
                  _ErrorBanner(message: error!, onRetry: () => onRefresh()),

                // Stat cards: one row of four on web, 2x2 on mobile.
                // Rows (not a fixed-ratio grid) so larger text sizes
                // can't overflow the cards.
                if (isWide)
                  _EvenRow(gap: 16, children: stats)
                else ...[
                  _EvenRow(gap: 12, children: stats.sublist(0, 2)),
                  SizedBox(height: 12),
                  _EvenRow(gap: 12, children: stats.sublist(2)),
                ],
                SizedBox(height: isWide ? 24 : 20),

                if (isWide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: recentPanel),
                        SizedBox(width: 20),
                        Expanded(flex: 2, child: weeklyPanel),
                      ],
                    ),
                  )
                else ...[
                  recentPanel,
                  SizedBox(height: 16),
                  weeklyPanel,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green gradient header with greeting + upload button.
class _HeroBanner extends StatelessWidget {
  final bool isWide;
  final String title;
  final String subtitle;
  final Widget action;
  final VoidCallback? onRefresh;

  const _HeroBanner({
    required this.isWide,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isWide ? 28 : 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brand, AppColors.brandLight],
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x332F7A4F), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: Icon(Icons.eco,
                  size: 170, color: Colors.white.withOpacity(0.10)),
            ),
            Positioned(
              right: 120,
              bottom: -40,
              child: Icon(Icons.local_florist,
                  size: 100, color: Colors.white.withOpacity(0.07)),
            ),
            Padding(
              padding: EdgeInsets.all(isWide ? 28 : 20),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(child: texts),
                        // Pull-to-refresh doesn't work with a mouse, so web
                        // gets an explicit refresh button.
                        IconButton(
                          tooltip: 'Refresh',
                          color: Colors.white,
                          onPressed: onRefresh,
                          icon: Icon(Icons.refresh),
                        ),
                        SizedBox(width: 8),
                        action,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        texts,
                        SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: action),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card with a tinted icon badge and a soft shadow.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays children out in one row with equal widths and equal heights.
class _EvenRow extends StatelessWidget {
  final double gap;
  final List<Widget> children;

  const _EvenRow({required this.gap, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: gap));
      items.add(Expanded(child: children[i]));
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class _RecentScansContent extends StatelessWidget {
  final bool loading;
  final bool isGuest;
  final List<HerbScan> scans;

  const _RecentScansContent({
    required this.loading,
    required this.isGuest,
    required this.scans,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _InlineLoading();

    if (scans.isEmpty) {
      return _EmptyNote(
        isGuest
            ? 'No scans yet. Sign up to start building your scan history.'
            : 'No scans yet. Upload a leaf photo to get started.',
      );
    }

    return Column(
      children: scans.map((scan) => ScanRow(scan: scan)).toList(),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
            child: Text('Try again'),
          ),
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
    final color = selected ? AppColors.brand : AppColors.textSecondary;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.bgAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : color,
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
  final Widget? trailing;
  final Widget child;

  const _Panel({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}