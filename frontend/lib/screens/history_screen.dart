import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/herb_scan.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../widgets/scan_row.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The user's full scan history, newest first, grouped by day.
///
/// [scans] is only shown while the full list loads, so the existing
/// `HistoryScreen(scans: ...)` call in the dashboard keeps working.
class HistoryScreen extends StatefulWidget {
  final List<HerbScan> scans;

  const HistoryScreen({super.key, this.scans = const []});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _all = 'All';
  static const _herbal = 'Herbal';
  static const _nonHerbal = 'Non-herbal';

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _isGuest = false;
  String? _error;
  late List<HerbScan> _scans;
  String _query = '';
  String _filter = _all;

  @override
  void initState() {
    super.initState();
    _scans = [...widget.scans];
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---- data ---------------------------------------------------------------

  HerbScan _fromJson(Map<String, dynamic> s) {
    final created = s['created_at'] as String?;
    return HerbScan(
      name: s['plant_name'] as String,
      latinName: (s['latin_name'] as String?) ?? '',
      confidence: (s['confidence'] as num).round(),
      scannedAt: created == null ? null : DateTime.parse(created).toLocal(),
    );
  }

  Future<void> _load() async {
    final auth = context.read<AuthState>();

    if (!auth.isLoggedIn || auth.token == null) {
      setState(() {
        _isGuest = true;
        _scans = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isGuest = false;
      _loading = true;
      _error = null;
    });

    try {
      final json = await ApiService.getScans(auth.token!);
      final scans = json.cast<Map<String, dynamic>>().map(_fromJson).toList()
        ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

      if (!mounted) return;
      setState(() {
        _scans = scans;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load your scan history.";
      });
    }
  }

  // ---- helpers ------------------------------------------------------------

  List<HerbScan> get _visible {
    final q = _query.trim().toLowerCase();
    return _scans.where((s) {
      final herbal = isHerbalScan(s);
      if (_filter == _herbal && !herbal) return false;
      if (_filter == _nonHerbal && herbal) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.latinName.toLowerCase().contains(q);
    }).toList();
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final base = '${_months[day.month - 1]} ${day.day}';
    return day.year == now.year ? base : '$base, ${day.year}';
  }

  String _timeLabel(DateTime d) => TimeOfDay.fromDateTime(d).format(context);

  void _openInfo(HerbScan scan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => _ScanInfoSheet(scan: scan, when: _timeLabel(scan.scannedAt)),
    );
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Scan history',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _scans.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    if (_error != null && _scans.isEmpty) {
      return _Empty(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        message: 'Check that the server is running, then try again.',
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_isGuest) {
      return const _Empty(
        icon: Icons.lock_outline,
        title: 'Sign up to keep a scan history',
        message: 'Guests can identify plants, but scans are only saved to an account.',
      );
    }

    if (_scans.isEmpty) {
      return const _Empty(
        icon: Icons.history,
        title: 'No scans yet',
        message: 'Upload a leaf photo from the dashboard and it will show up here.',
      );
    }

    final visible = _visible;

    // Group by calendar day, keeping newest first.
    final groups = <DateTime, List<HerbScan>>{};
    for (final s in visible) {
      final d = s.scannedAt;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(s);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummary(),
                  const SizedBox(height: 16),
                  _buildSearch(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '$_error Showing the last loaded scans.',
                        style: TextStyle(fontSize: 13, color: AppColors.danger),
                      ),
                    ),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: _Empty(
                        icon: Icons.search_off,
                        title: 'No scans found',
                        message: 'Try a different name or change the filter.',
                      ),
                    ),
                  for (final entry in groups.entries) _buildGroup(entry.key, entry.value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final herbalCount = _scans.where(isHerbalScan).length;
    final avg = _scans.isEmpty
        ? 0
        : (_scans.fold<int>(0, (a, s) => a + s.confidence) / _scans.length)
            .round();

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.document_scanner_outlined,
            label: 'Total scans',
            value: '${_scans.length}',
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.eco_outlined,
            label: 'Herbal',
            value: '$herbalCount',
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.verified_outlined,
            label: 'Avg. confidence',
            value: '$avg%',
            color: AppColors.accentAmber,
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search your scans',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius + 4),
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const options = [_all, _herbal, _nonHerbal];
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: _filter == o,
            onSelected: (_) => setState(() => _filter = o),
            showCheckmark: false,
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.brand,
            side: BorderSide(
                color: _filter == o ? AppColors.brand : AppColors.border),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _filter == o ? AppColors.onBrand : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildGroup(DateTime day, List<HerbScan> scans) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _dayLabel(day),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  scans.length == 1 ? '1 scan' : '${scans.length} scans',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < scans.length; i++)
              ScanRow(
                scan: scans[i],
                meta: _timeLabel(scans[i].scannedAt),
                showDivider: i != scans.length - 1,
                onTap: () => _openInfo(scans[i]),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.bgAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.brand),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: BorderSide(color: AppColors.brand),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the stored information for one scanned plant.
class _ScanInfoSheet extends StatefulWidget {
  final HerbScan scan;
  final String when;

  const _ScanInfoSheet({required this.scan, required this.when});

  @override
  State<_ScanInfoSheet> createState() => _ScanInfoSheetState();
}

class _ScanInfoSheetState extends State<_ScanInfoSheet> {
  late final Future<Map<String, dynamic>?> _info;

  @override
  void initState() {
    super.initState();
    _info = widget.scan.latinName.isEmpty
        ? Future.value(null)
        : ApiService.getHerbInfo(widget.scan.latinName);
  }

  Widget _section(String title, String? text, {bool warn = false}) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    final fg = warn ? AppColors.textWarning : AppColors.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warn ? AppColors.bgWarning : AppColors.bgAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              scan.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            if (scan.latinName.isNotEmpty)
              Text(
                scan.latinName,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Identified at ${widget.when} with ${scan.confidence}% confidence',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: _info,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final info = snap.data;
                if (info == null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      'More information about this plant is coming soon.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((info['description'] as String?)?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          info['description'] as String,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    _section('Benefits', info['benefits'] as String?),
                    _section('Traditional uses',
                        info['traditional_uses'] as String?),
                    _section('Risks', info['risks'] as String?, warn: true),
                    _section('Precautions', info['precautions'] as String?,
                        warn: true),
                    const SizedBox(height: 16),
                    Text(
                      'For general information only. This is not medical advice.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}