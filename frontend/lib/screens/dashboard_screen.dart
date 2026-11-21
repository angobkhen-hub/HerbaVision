// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/herb_scan.dart';
import '../theme/app_colors.dart';
import '../theme/app_animations.dart';
import '../theme/herba_ui.dart';
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

/// Species the library marks as non-herbal (used if the lookup has no category).
const Set<String> _kNonHerbalLatin = {
  'caladium bicolor',
  'dieffenbachia seguine',
  'dracaena reflexa',
};

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
  // The app shell keeps one route and only swaps the content area, so the
  // sidebar never disappears while the user moves between sections.
  int _section = 0; // 0 dashboard, 1 library, 2 history, 3 report, 4 settings
  final Set<int> _visited = {0};

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
    // The scanner opens as a popup over the current section instead of a
    // pushed page, so the shell and its navigation stay in place.
    final upload = await showDialog<UploadResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: media.size.width >= _kWideBreakpoint ? 48 : 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: media.size.height - 48,
            ),
            child: const UploadScreen(popup: true),
          ),
        );
      },
    );
    if (upload == null || !mounted) return;
    final result = upload.scan;

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
    await _showResultDialog(result, note, upload.imageBytes);
  }

  Future<void> _showResultDialog(
      HerbScan result, String? note, Uint8List imageBytes) async {
    // Look up the herb's stored information (leaf_items table). If it can't be
    // loaded, the dialog still shows the identification result.
    dynamic info;
    try {
      info = await ApiService.getHerbInfo(result.latinName);
    } catch (_) {
      info = null; // the dialog still opens, with "coming soon" text
    }
    if (!mounted) return;

    // Non-herbal leaves keep their name, Latin name and information, but the
    // confidence is hidden and a "non-herbal" message is shown.
    final category =
        ((info?['category'] as String?) ?? '').trim().toLowerCase();
    final nonHerbal = category == 'non-herbal' ||
        _kNonHerbalLatin.contains(result.latinName.trim().toLowerCase());
    final scan = result;

    // One information card: tinted icon badge, title, text.
    // [big] is used by the wide (web) layout.
    Widget section(String title, String? text, IconData icon, Color color,
        {bool big = false}) {
      if (text == null || text.trim().isEmpty) return SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: big ? 14 : 12),
        padding: EdgeInsets.all(big ? 18 : 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(big ? 18 : 16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: big ? 42 : 34,
              height: big ? 42 : 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(big ? 12 : 10),
              ),
              child: Icon(icon, size: big ? 22 : 18, color: color),
            ),
            SizedBox(width: big ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: big ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: big ? 14.5 : 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final wide = size.width >= _kWideBreakpoint;

        // Confidence, save status and the information cards.
        // Same content for both layouts; sizes grow on wide screens.
        Widget bodyContent() {
          // Non-herbal: say so and hide the confidence, but keep the leaf information.
          if (nonHerbal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(wide ? 18 : 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgWarning,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.textWarning.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_florist_outlined,
                          size: wide ? 26 : 22, color: AppColors.textWarning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This leaf is non-herbal.',
                          style: TextStyle(
                            fontSize: wide ? 18 : 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (note != null) ...[
                  SizedBox(height: 14),
                  Text(
                    note,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSuccess),
                  ),
                ],
                if (info == null) ...[
                  SizedBox(height: 14),
                  Text(
                    'More information about this plant is coming soon.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
                section('About', info?['description'] as String?,
                    Icons.info_outline, AppColors.brand,
                    big: wide),
                section('Benefits', info?['benefits'] as String?,
                    Icons.spa_outlined, AppColors.accentBlue,
                    big: wide),
                section('Traditional uses',
                    info?['traditional_uses'] as String?,
                    Icons.menu_book_outlined, AppColors.accentPurple,
                    big: wide),
                section('Risks', info?['risks'] as String?,
                    Icons.warning_amber_rounded, AppColors.accentAmber,
                    big: wide),
                section('Precautions', info?['precautions'] as String?,
                    Icons.shield_outlined, AppColors.accentAmber,
                    big: wide),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: wide ? 22 : 18, color: AppColors.brand),
                  SizedBox(width: 8),
                  Text(
                    'Confidence',
                    style: TextStyle(
                      fontSize: wide ? 15 : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${scan.confidence}%',
                    style: TextStyle(
                      fontSize: wide ? 26 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textAccent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: wide ? 10 : 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (scan.confidence / 100).clamp(0.0, 1.0),
                  minHeight: wide ? 10 : 8,
                  backgroundColor: AppColors.bgAccent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
              if (note != null) ...[
                SizedBox(height: wide ? 18 : 14),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: wide ? 14 : 12, vertical: wide ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: wide ? 18 : 16, color: AppColors.textSuccess),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: wide ? 14 : 12.5,
                            color: AppColors.textSuccess,
                          ),
                        ),
                      ),
                    ],
                  ),
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
              section('About', info?['description'] as String?,
                  Icons.info_outline, AppColors.brand,
                  big: wide),
              section('Benefits', info?['benefits'] as String?,
                  Icons.spa_outlined, AppColors.accentBlue,
                  big: wide),
              section('Traditional uses', info?['traditional_uses'] as String?,
                  Icons.menu_book_outlined, AppColors.accentPurple,
                  big: wide),
              section('Risks', info?['risks'] as String?,
                  Icons.warning_amber_rounded, AppColors.accentAmber,
                  big: wide),
              section('Precautions', info?['precautions'] as String?,
                  Icons.shield_outlined, AppColors.accentAmber,
                  big: wide),
            ],
          );
        }

        Widget doneButton() {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: wide ? 18 : 14),
                textStyle: TextStyle(
                    fontSize: wide ? 16 : 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                ),
              ),
              child: Text('Done'),
            ),
          );
        }

        // ------------------------------------------------------------------
        // WEB: big two-column dialog, photo on the left, details on the right.
        // ------------------------------------------------------------------
        if (wide) {
          final height = (size.height - 48).clamp(480.0, 720.0).toDouble();
          return Dialog(
            backgroundColor: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: SizedBox(
              width: 980,
              height: height,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: the photo with the name on it
                      SizedBox(
                        width: 400,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(imageBytes, fit: BoxFit.cover),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.78),
                                  ],
                                  stops: [0.5, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 28,
                              right: 28,
                              bottom: 28,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    scan.name,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                      height: 1.1,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (scan.latinName.isNotEmpty) ...[
                                    SizedBox(height: 6),
                                    Text(
                                      scan.latinName,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: details + button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(36, 60, 36, 12),
                                child: bodyContent(),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(36, 8, 36, 28),
                              child: doneButton(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: AppColors.bgAccent,
                      shape: CircleBorder(),
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(Icons.close,
                              size: 20, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ------------------------------------------------------------------
        // MOBILE: single column (unchanged look)
        // ------------------------------------------------------------------
        return Dialog(
          backgroundColor: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 460, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 250,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(imageBytes, fit: BoxFit.cover),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.72),
                                    ],
                                    stops: [0.45, 1.0],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.black.withOpacity(0.35),
                                  shape: CircleBorder(),
                                  child: InkWell(
                                    customBorder: CircleBorder(),
                                    onTap: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.close,
                                          size: 20, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      scan.name,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (scan.latinName.isNotEmpty) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        scan.latinName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.white.withOpacity(0.88),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: bodyContent(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: doneButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Switches the visible section without pushing a new route, so the
  /// navigation rail stays in place.
  void _selectSection(int index) {
    if (_section == index) return;
    setState(() {
      _section = index;
      _visited.add(index);
    });
  }

  void _openHistory() => _selectSection(2);

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

  /// The content for one navigation section. Every page is embedded in the
  /// shell, so it renders without its own app bar or push transition.
  Widget _sectionPage(int index, {required bool isWide}) {
    switch (index) {
      case 1:
        return const LibraryScreen(embedded: true);
      case 2:
        return HistoryScreen(scans: _recentScans, embedded: true);
      case 3:
        return const ReportFormScreen(embedded: true);
      case 4:
        return const SettingsScreen(embedded: true);
      case 0:
      default:
        return _buildBody(isWide: isWide);
    }
  }

  /// Keeps every visited section alive so scroll position, search text and
  /// loaded data survive while switching tabs.
  Widget _buildSections({required bool isWide}) {
    return IndexedStack(
      index: _section,
      children: [
        for (var i = 0; i < 5; i++)
          SizedBox.expand(
            child: _visited.contains(i)
                ? _sectionPage(i, isWide: isWide)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _kWideBreakpoint;

          // WEB: permanent sidebar + content that swaps in place.
          if (isWide) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 286,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.isDark
                            ? const [Color(0xF20B1510), Color(0xF2070D09)]
                            : const [Color(0xFAFFFFFF), Color(0xF2EFF6ED)],
                      ),
                      border: Border(
                        right: BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                    child: _SidebarContent(
                      selectedIndex: _section,
                      onSelect: _selectSection,
                    ),
                  ),
                  Expanded(
                    child: SafeArea(child: _buildSections(isWide: true)),
                  ),
                ],
              ),
            );
          }

          // MOBILE: app bar + a bottom bar that is always visible.
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
            body: SafeArea(child: _buildSections(isWide: false)),
            bottomNavigationBar: _MobileNav(
              selectedIndex: _section,
              onSelect: _selectSection,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display widgets
// ---------------------------------------------------------------------------

/// Page background: aurora orbs, blueprint grid and drifting leaves.
class _AppBackground extends StatelessWidget {
  final Widget child;
  const _AppBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return HerbaBackdrop(
      intensity: AppColors.dark ? 1.0 : 1.1,
      child: child,
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return HerbaLogo(size: size);
  }
}

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _SidebarContent({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final name = authState.userName ?? 'Guest';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  HerbaLogo(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HerbaVision',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        MicroLabel(
                          'Botanical AI',
                          color: AppColors.textMuted,
                          dot: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: MicroLabel('Workspace', color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            _DrawerItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _DrawerItem(
              icon: Icons.local_florist_outlined,
              label: 'Herb library',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _DrawerItem(
              icon: Icons.history_rounded,
              label: 'History',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _DrawerItem(
              icon: Icons.assignment_outlined,
              label: 'Report form',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            _DrawerItem(
              icon: Icons.tune_rounded,
              label: 'Settings',
              selected: selectedIndex == 4,
              onTap: () => onSelect(4),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emerald.withAlpha(AppColors.isDark ? 22 : 16),
                      AppColors.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.emerald.withAlpha(AppColors.isDark ? 55 : 40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HerbaPill('Vision core online'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.emerald.withAlpha(AppColors.isDark ? 40 : 28),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontFamily: 'Sora',
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                authState.isGuest
                                    ? 'Browsing as guest'
                                    : 'Signed in',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 9.5,
                                  letterSpacing: 0.6,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }
}

/// Fixed bottom navigation used on narrow (phone-sized) screens.
class _MobileNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MobileNav({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lime.withAlpha(AppColors.isDark ? 55 : 45),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_florist_outlined),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          label: 'Report',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          label: 'Settings',
        ),
      ],
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

    final uploadButton = NeonButton(
      onPressed: onUpload,
      icon: Icons.add_a_photo_outlined,
      label: 'Scan a leaf',
    );

    final stats = <Widget>[
      FadeSlideIn(
        delay: const Duration(milliseconds: 80),
        child: _StatTile(
          label: 'Total scans',
          value: loading ? '—' : '$totalScans',
          animateTo: loading ? null : totalScans,
          icon: Icons.document_scanner_outlined,
          color: AppColors.lime,
        ),
      ),
      FadeSlideIn(
        delay: const Duration(milliseconds: 150),
        child: _StatTile(
          label: 'Species identified',
          value: loading ? '—' : '$speciesIdentified',
          animateTo: loading ? null : speciesIdentified,
          icon: Icons.local_florist_outlined,
          color: AppColors.cyan,
        ),
      ),
      FadeSlideIn(
        delay: const Duration(milliseconds: 220),
        child: _StatTile(
          label: 'Avg. confidence',
          value: loading
              ? '—'
              : (hasAnyScans ? '${avgConfidence.round()}%' : '—'),
          animateTo: loading || !hasAnyScans ? null : avgConfidence,
          suffix: '%',
          icon: Icons.verified_outlined,
          color: AppColors.accentAmber,
        ),
      ),
      FadeSlideIn(
        delay: const Duration(milliseconds: 290),
        child: _StatTile(
          label: 'Saved to library',
          value: loading ? '—' : '$savedToLibrary',
          animateTo: loading ? null : savedToLibrary,
          icon: Icons.bookmark_border_rounded,
          color: AppColors.accentPurple,
        ),
      ),
    ];

    final recentPanel = FadeSlideIn(
      delay: const Duration(milliseconds: 320),
      child: _Panel(
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
      ),
    );

    final weeklyPanel = FadeSlideIn(
      delay: const Duration(milliseconds: 400),
      child: _Panel(
        title: 'Weekly scan activity',
        trailing: loading || weekTotal == 0
            ? null
            : HerbaPill(
                '$weekTotal this week',
                icon: Icons.bolt_rounded,
                color: AppColors.lime,
              ),
        child: loading
            ? _InlineLoading()
            : weekTotal == 0
                ? _EmptyNote('No scans in the last 7 days.')
                : WeeklyChart(values: weeklyActivity),
      ),
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

/// Green gradient header with greeting + upload button, a slow light sweep and
/// gently bobbing leaves.
class _HeroBanner extends StatefulWidget {
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
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
      value: 0.35,
    );
    // The endless light-sweep animation is heavy on phones, so it runs
    // only on wide (desktop) screens.
    if (widget.isWide) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWide != oldWidget.isWide) {
      if (widget.isWide) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.isWide;
    final reticleSize = wide ? 250.0 : 190.0;

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MicroLabel('Live session', color: AppColors.emerald),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 12,
              color: Colors.white.withAlpha(40),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'LEAF SCANNER READY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  color: Colors.white.withAlpha(140),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: wide ? 34 : 26,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 520 : 600),
          child: Text(
            widget.subtitle,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 14.5,
              height: 1.5,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            HerbaPill('Vision core online'),
            HerbaPill('6 species indexed', icon: Icons.eco_outlined),
            HerbaPill('Real-time', icon: Icons.bolt_rounded),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            PressableScale(child: widget.action),
            if (wide) ...[
              const SizedBox(width: 10),
              _GlassIconButton(
                tooltip: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: widget.onRefresh,
              ),
            ],
          ],
        ),
      ],
    );

    return FadeSlideIn(
      offset: const Offset(0, 0.06),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123020), Color(0xFF0A1B12)],
          ),
          border: Border.all(color: AppColors.emerald.withAlpha(45)),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald.withAlpha(AppColors.isDark ? 34 : 20),
              blurRadius: 46,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  final bob = math.sin(t * math.pi * 2);
                  return Stack(
                    children: [
                      // Aurora glow behind the reticle.
                      Positioned(
                        right: -70,
                        top: -90 + bob * 6,
                        child: Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.emerald.withAlpha(60),
                                AppColors.lime.withAlpha(16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Technical reticle.
                      Positioned(
                        right: wide ? 36 : -58,
                        top: wide ? null : -42,
                        bottom: wide ? 12 : null,
                        child: Opacity(
                          opacity: wide ? 0.95 : 0.5,
                          child: ScanReticle(
                            size: reticleSize,
                            color: AppColors.emerald,
                          ),
                        ),
                      ),
                      // Glass sheen sweeping across the card.
                      Positioned(
                        left: -220 + (width + 440) * t,
                        top: -120,
                        child: Transform.rotate(
                          angle: -0.32,
                          child: Container(
                            width: 150,
                            height: 420,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withAlpha(0),
                                  Colors.white.withAlpha(18),
                                  Colors.white.withAlpha(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Top hairline.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.lime.withAlpha(0),
                                AppColors.lime.withAlpha(120),
                                AppColors.emerald.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(wide ? 32 : 22),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 660 : double.infinity,
                          ),
                          child: texts,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Small translucent icon button used on top of the hero card.
class _GlassIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withAlpha(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withAlpha(40)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, size: 20, color: Colors.white.withAlpha(220)),
          ),
        ),
      ),
    );
  }
}

/// Stat card with a tinted icon badge, a soft glow and a count-up number.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  /// When set, the number counts up from 0 to this value.
  final num? animateTo;
  final String suffix;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.animateTo,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontFamily: 'Sora',
      fontSize: 30,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      color: AppColors.textPrimary,
    );

    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                color.withAlpha(AppColors.isDark ? 22 : 12),
                AppColors.surface,
              ),
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withAlpha(AppColors.isDark ? 48 : 34),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(AppColors.isDark ? 16 : 8),
              blurRadius: 26,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(AppColors.isDark ? 26 : 20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 38,
              child: Align(
                alignment: Alignment.centerLeft,
                child: animateTo == null
                    ? Text(value, style: valueStyle)
                    : AnimatedCounter(
                        value: animateTo!,
                        suffix: suffix,
                        style: valueStyle,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Container(color: AppColors.border),
                    FractionallySizedBox(
                      widthFactor: 0.42,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withAlpha(120), color],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      children: [
        for (var i = 0; i < scans.length; i++)
          FadeSlideIn(
            delay: Duration(milliseconds: 60 * i),
            offset: const Offset(0.06, 0),
            child: ScanRow(
              scan: scans[i],
              showDivider: i != scans.length - 1,
            ),
          ),
      ],
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
    final tint = AppColors.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: tint.withAlpha(AppColors.isDark ? 26 : 16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: tint),
            child: const Text('Try again'),
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
    final color = selected ? AppColors.lime : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: AnimatedContainer(
            duration: HerbaMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppColors.lime.withAlpha(AppColors.isDark ? 26 : 20),
                        AppColors.lime.withAlpha(0),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(13),
              border: selected
                  ? Border.all(
                      color: AppColors.lime.withAlpha(AppColors.isDark ? 55 : 45),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? AppColors.textPrimary : color,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.lime.withAlpha(150),
                          blurRadius: 8,
                        ),
                      ],
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
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withAlpha(120),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}