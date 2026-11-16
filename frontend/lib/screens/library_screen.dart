// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/herba_ui.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

// ---------------------------------------------------------------------------
// Model: mirrors one row of the leaf_items table as returned by GET /herbs/
// ---------------------------------------------------------------------------

class _Herb {
  final int id;
  final String fullName; // "Sambong (Alib-on, Gabon) - Blumea balsamifera"
  final String commonName; // "Sambong"
  final String aliases; // "Alib-on, Gabon"
  final String latinName; // "Blumea balsamifera"
  final String category; // "Herbal" / "Non-herbal"
  final String description;
  final String benefits;
  final String traditionalUses;
  final String risks;
  final String precautions;

  const _Herb({
    required this.id,
    required this.fullName,
    required this.commonName,
    required this.aliases,
    required this.latinName,
    required this.category,
    required this.description,
    required this.benefits,
    required this.traditionalUses,
    required this.risks,
    required this.precautions,
  });

  bool get isHerbal => category.toLowerCase() == 'herbal';

  /// Key used to match against the user's saved herbs.
  String get key => latinName.trim().toLowerCase();

  factory _Herb.fromJson(Map<String, dynamic> j) {
    String s(String k) => ((j[k] as String?) ?? '').trim();

    final full = s('name');

    // The name column is stored as "Common (Aliases) - Latin name".
    var left = full;
    var latin = '';
    final dash = full.lastIndexOf(' - ');
    if (dash != -1) {
      left = full.substring(0, dash).trim();
      latin = full.substring(dash + 3).trim();
    }

    var common = left;
    var aliases = '';
    final open = left.indexOf('(');
    if (open != -1) {
      common = left.substring(0, open).trim();
      final close = left.lastIndexOf(')');
      aliases = left
          .substring(open + 1, close > open ? close : left.length)
          .trim();
    }

    return _Herb(
      id: (j['id'] as num?)?.toInt() ?? 0,
      fullName: full,
      commonName: common.isEmpty ? full : common,
      aliases: aliases,
      latinName: latin,
      category: s('category').isEmpty ? 'Uncategorized' : s('category'),
      description: s('description'),
      benefits: s('benefits'),
      traditionalUses: s('traditional_uses'),
      risks: s('risks'),
      precautions: s('precautions'),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LibraryScreen extends StatefulWidget {
  /// When true the page renders inside the app shell, without its own
  /// Scaffold, app bar or background.
  final bool embedded;

  const LibraryScreen({super.key, this.embedded = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
 static const String _all = 'All';
 static const String _savedFilter = 'Saved';

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_Herb> _herbs = [];
  final Set<String> _saved = {};
  String _query = '';
  String _filter = _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---- data ---------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthState>();
    final token = auth.isLoggedIn ? auth.token : null;

    try {
      final herbsFuture = ApiService.getHerbs();
      // A failure loading saved herbs shouldn't hide the whole library.
      final savedFuture = token == null
          ? Future.value(<dynamic>[])
          : ApiService.getSavedHerbs(token).catchError((_) => <dynamic>[]);

      final herbsJson = await herbsFuture;
      final savedJson = await savedFuture;

      final herbs = herbsJson
          .cast<Map<String, dynamic>>()
          .map(_Herb.fromJson)
          .toList()
        ..sort((a, b) =>
            a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()));

      final saved = savedJson
          .map((e) => ((e as Map)['latin_name'] as String? ?? '')
              .trim()
              .toLowerCase())
          .where((k) => k.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() {
        _herbs = herbs;
        _saved
          ..clear()
          ..addAll(saved);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load the herb library.";
      });
    }
  }

  bool _isSaved(_Herb h) => _saved.contains(h.key);

  Future<void> _toggleSaved(_Herb herb) async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up to save herbs to your library.')),
      );
      return;
    }
    if (herb.latinName.isEmpty) return;

    final nowSaved = !_isSaved(herb);

    // Update the UI right away, then undo if the server rejects it.
    setState(() {
      nowSaved ? _saved.add(herb.key) : _saved.remove(herb.key);
    });

    try {
      await ApiService.setHerbSaved(
        token: auth.token!,
        latinName: herb.latinName,
        saved: nowSaved,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        nowSaved ? _saved.remove(herb.key) : _saved.add(herb.key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update saved herbs. Try again.")),
      );
    }
  }

  // ---- filtering ----------------------------------------------------------

  List<String> get _categories {
    final set = <String>{};
    for (final h in _herbs) {
      set.add(h.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<_Herb> get _visible {
    final q = _query.trim().toLowerCase();
    return _herbs.where((h) {
      if (_filter == _savedFilter && !_isSaved(h)) return false;
      if (_filter != _all && _filter != _savedFilter && h.category != _filter) {
        return false;
      }
      if (q.isEmpty) return true;
      return h.commonName.toLowerCase().contains(q) ||
          h.latinName.toLowerCase().contains(q) ||
          h.aliases.toLowerCase().contains(q) ||
          h.category.toLowerCase().contains(q);
    }).toList();
  }

  // ---- detail -------------------------------------------------------------

  void _openDetail(_Herb herb) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheet) => _DetailSheet(
          herb: herb,
          saved: _isSaved(herb),
          onToggleSaved: () async {
            await _toggleSaved(herb);
            if (ctx.mounted) setSheet(() {});
          },
        ),
      ),
    );
  }

  // ---- build --------------------------------------------------------------

  /// The searchable list, shared by the standalone page and the app shell.
  Widget _buildContentColumn(List<_Herb> visible) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearch(),
                  const SizedBox(height: 14),
                  _buildFilters(),
                  const SizedBox(height: 14),
                  if (!_loading && _error == null)
                    MicroLabel(
                      _filter == _all && _query.isEmpty
                          ? '${_herbs.length} plants · ${_saved.length} saved'
                          : '${visible.length} of ${_herbs.length} plants',
                      color: AppColors.textMuted,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(child: _buildContent(visible)),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Herb library',
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    // Embedded in the persistent app shell: no separate page chrome.
    if (widget.embedded) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInlineHeader(),
            Expanded(child: _buildContentColumn(visible)),
          ],
        ),
      );
    }

    return HerbaBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          title: Text(
            'Herb library',
            style: TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh_rounded),
            ),
            SizedBox(width: 4),
          ],
        ),
        body: SafeArea(child: _buildContentColumn(visible)),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search by name, local name, or scientific name',
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon:
            Icon(Icons.search, size: 20, color: AppColors.textMuted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(vertical: 14),
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
    final options = [_all, ..._categories, _savedFilter];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o == _savedFilter ? 'Saved (${_saved.length})' : o),
                selected: _filter == o,
                onSelected: (_) => setState(() => _filter = o),
                showCheckmark: false,
                backgroundColor: AppColors.glass,
                selectedColor: AppColors.lime,
                side: BorderSide(
                  color: _filter == o
                      ? AppColors.lime.withAlpha(120)
                      : AppColors.glassBorder,
                ),
                labelStyle: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: _filter == o
                      ? AppColors.onBrand
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(List<_Herb> visible) {
    // LOADING
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 14),
            Text(
              'Loading: fetching the herb library…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // ERROR
    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Error: ${_error!}',
        message: 'Check that the server is running, then try again.',
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    // EMPTY: the database has no herbs at all
    if (_herbs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          SizedBox(height: 60),
          _StateMessage(
            icon: Icons.menu_book_outlined,
            title: 'Empty: the library has no herbs yet',
            message: 'No herbs have been added to the database yet.',
          ),
        ]),
      );
    }

    // EMPTY: nothing matches the search or filter
    if (visible.isEmpty) {
      final onSaved = _filter == _savedFilter && _query.isEmpty;
      return _StateMessage(
        icon: onSaved ? Icons.bookmark_border : Icons.search_off,
        title: onSaved ? 'Empty: no saved herbs yet' : 'Empty: no herbs found',
        message: onSaved
            ? 'Tap the bookmark on any herb to keep it here.'
            : 'Try a different name or clear the filter.',
        actionLabel: onSaved ? 'Browse all herbs' : 'Clear search and filter',
        onAction: () {
          _searchController.clear();
          setState(() {
            _query = '';
            _filter = _all;
          });
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
        physics: AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 214,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final herb = visible[i];
          return FadeSlideIn(
            delay: Duration(milliseconds: 45 * (i % 8)),
            offset: const Offset(0, 0.08),
            child: HoverLift(
              child: _HerbCard(
                herb: herb,
                saved: _isSaved(herb),
                onTap: () => _openDetail(herb),
                onToggleSaved: () => _toggleSaved(herb),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  final _Herb herb;
  const _CategoryChip({required this.herb});

  @override
  Widget build(BuildContext context) {
    final herbal = herb.isHerbal;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: herbal ? AppColors.bgSuccess : AppColors.bgWarning,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        herb.category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: herbal ? AppColors.textSuccess : AppColors.textWarning,
        ),
      ),
    );
  }
}

class _HerbCard extends StatelessWidget {
  final _Herb herb;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  const _HerbCard({
    required this.herb,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: saved
                  ? AppColors.lime.withAlpha(AppColors.isDark ? 90 : 70)
                  : AppColors.glassBorder,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: herb.isHerbal
                          ? AppColors.brand.withAlpha(AppColors.isDark ? 26 : 18)
                          : AppColors.bgWarning,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: herb.isHerbal
                            ? AppColors.brand.withAlpha(60)
                            : AppColors.textWarning.withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      herb.isHerbal ? Icons.eco : Icons.local_florist_outlined,
                      size: 22,
                      color: herb.isHerbal
                          ? AppColors.textAccent
                          : AppColors.textWarning,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            herb.commonName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (herb.latinName.isNotEmpty)
                            Text(
                              herb.latinName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: saved ? 'Remove from saved' : 'Save herb',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleSaved,
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      color: saved ? AppColors.lime : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text(
                  herb.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Spacer(),
              Row(
                children: [
                  _CategoryChip(herb: herb),
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                      'View details',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final _Herb herb;
  final bool saved;
  final Future<void> Function() onToggleSaved;

  const _DetailSheet({
    required this.herb,
    required this.saved,
    required this.onToggleSaved,
  });

  Widget _section(String title, String text, IconData icon,
      {Color? tint, Color? tintBg}) {
    if (text.isEmpty) return SizedBox.shrink();
    final fg = tint ?? AppColors.brand;
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tintBg ?? AppColors.bgAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: fg),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(22, 10, 22, 28),
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
            SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        herb.commonName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (herb.latinName.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          herb.latinName,
                          style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (herb.aliases.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          'Also known as ${herb.aliases}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      SizedBox(height: 10),
                      _CategoryChip(herb: herb),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onToggleSaved,
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                  ),
                  label: Text(saved ? 'Saved' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        saved ? AppColors.bgAccent : AppColors.brand,
                    foregroundColor:
                        saved ? AppColors.brand : AppColors.onBrand,
                  ),
                ),
              ],
            ),
            if (herb.description.isNotEmpty) ...[
              SizedBox(height: 18),
              Text(
                herb.description,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            SizedBox(height: 6),
            _section('Benefits', herb.benefits, Icons.favorite_border),
            _section('Traditional uses', herb.traditionalUses,
                Icons.history_edu_outlined),
            _section('Risks', herb.risks, Icons.warning_amber_rounded,
                tint: AppColors.textWarning, tintBg: AppColors.bgWarning),
            _section('Precautions', herb.precautions, Icons.shield_outlined,
                tint: AppColors.textWarning, tintBg: AppColors.bgWarning),
            SizedBox(height: 18),
            Text(
              'For general information only. This is not medical advice.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
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
        padding: EdgeInsets.all(32),
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
            SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
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
              SizedBox(height: 16),
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