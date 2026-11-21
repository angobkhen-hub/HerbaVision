import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/herba_ui.dart';

// ---------------------------------------------------------------------------
// Report form
//
// Shows the four required states:
//   LOADING : "Loading: submitting your report…", button disabled
//   SUCCESS : "Success: report submitted", with a reference number and next actions
//   EMPTY   : "Empty: no reports yet" in the My reports list, with a Create button
//   ERROR   : "Error: …" with a Retry button
//
// Reports are sent to the backend (POST /reports) and loaded from
// GET /reports/me through ApiService.
// ---------------------------------------------------------------------------

/// How long the simulated submission takes, so Loading can be screenshotted.
/// Set to Duration.zero for a normal, instant submission.
// ignore: unused_element
const Duration _kSubmitDelay = Duration(seconds: 4);

const _loadingInk = Color(0xFF9BD8FF);
const _loadingBg = Color(0xFF0E2233);
const _loadingLine = Color(0xFF1E4A66);
const _successBg = Color(0xFF0F2C1B);
const _successLine = Color(0xFF2A6B45);
const _successInk = Color(0xFF9BFFC0);

const List<String> _reportTypes = [
  'Wrong identification',
  'Missing herb information',
  'App problem',
  'Other',
];

enum _SubmitState { idle, loading, success, error }

class _Report {
  final String id;
  final String type;
  final String title;
  final String details;
  final DateTime createdAt;

  const _Report({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.createdAt,
  });

  factory _Report.fromJson(Map<String, dynamic> j) => _Report(
        id: 'R-${j['id']}',
        type: j['type'] as String,
        title: j['title'] as String,
        details: j['description'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class ReportFormScreen extends StatefulWidget {
  /// When true the page renders inside the app shell, without its own
  /// Scaffold, app bar or background.
  final bool embedded;

  const ReportFormScreen({super.key, this.embedded = false});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final _titleFocus = FocusNode();
  final _scrollController = ScrollController();

  String _type = _reportTypes.first;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  _SubmitState _state = _SubmitState.idle;
  String? _lastReportId;

  final List<_Report> _reports = [];
  bool _loadingReports = true;

  bool get _loading => _state == _SubmitState.loading;

  /// The signed-in user's login token (null for guests / logged out).
  String? get _token => context.read<AuthState>().token;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _titleFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---- logic --------------------------------------------------------------

  Future<void> _loadReports() async {
    final token = _token;
    if (token == null) {
      // Guest or logged out: there are no saved reports to load.
      if (mounted) setState(() => _loadingReports = false);
      return;
    }
    try {
      final list = await ApiService.fetchMyReports(token);
      if (!mounted) return;
      setState(() {
        _reports
          ..clear()
          ..addAll(list.map((j) => _Report.fromJson(j)));
        _loadingReports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReports = false);
    }
  }

  String? _validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter a short title';
    return null;
  }

  String? _validateDetails(String? v) {
    if (v == null || v.trim().isEmpty) return 'Describe the problem';
    if (v.trim().length < 10) return 'Please write at least 10 characters';
    return null;
  }

  void _onEdited() {
    // Editing after a result clears the old message.
    if (_state == _SubmitState.success || _state == _SubmitState.error) {
      setState(() => _state = _SubmitState.idle);
    }
  }

  Future<void> _submit() async {
    if (_loading) return; // prevents duplicate submissions

    // Blank or invalid fields: explain what is missing, send nothing.
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _state = _SubmitState.loading);

    final token = _token;
    if (token == null) {
      // Guests can't submit reports.
      setState(() => _state = _SubmitState.error);
      return;
    }

    try {
      final json = await ApiService.submitReport(
        token: token,
        type: _type,
        title: _titleController.text.trim(),
        description: _detailsController.text.trim(),
      );
      if (!mounted) return;
      final report = _Report.fromJson(json);
      setState(() {
        _reports.insert(0, report);
        _lastReportId = report.id;
        _state = _SubmitState.success;
        _titleController.clear();
        _detailsController.clear();
        _autovalidate = AutovalidateMode.disabled;
        _type = _reportTypes.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _SubmitState.error);
    }
  }

  void _startNewReport() {
    setState(() => _state = _SubmitState.idle);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _titleFocus.requestFocus();
  }

  void _showMyReports() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ---- display ------------------------------------------------------------

  InputDecoration _decoration(String label, {String? hint}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.brand, 1.8),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400, 1.8),
    );
  }

  Widget _statusBox({
    required Color background,
    required Color borderColor,
    required Widget leading,
    required String label,
    required String text,
    required Color textColor,
    String? extra,
    List<Widget> actions = const [],
  }) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(top: 1), child: leading),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$label: ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: text),
                      ],
                    ),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (extra != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 30),
                child: Text(extra,
                    style: TextStyle(fontSize: 13, color: textColor)),
              ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: actions,
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Widget? banner;

    switch (_state) {
      case _SubmitState.loading:
        banner = _statusBox(
          background: _loadingBg,
          borderColor: _loadingLine,
          leading: const SizedBox(
            height: 18,
            width: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2.2, color: _loadingInk),
          ),
          label: 'Loading',
          text: 'Submitting your report…',
          textColor: _loadingInk,
        );
        break;
      case _SubmitState.success:
        banner = _statusBox(
          background: _successBg,
          borderColor: _successLine,
          leading: Icon(Icons.check_circle, color: AppColors.brand, size: 20),
          label: 'Success',
          text: 'Report submitted. Thank you!',
          textColor: _successInk,
          extra: 'Your reference number is ${_lastReportId ?? ''}.',
          actions: [
            TextButton(
              onPressed: _showMyReports,
              style: TextButton.styleFrom(foregroundColor: _successInk),
              child: const Text('View my reports'),
            ),
            TextButton(
              onPressed: _startNewReport,
              style: TextButton.styleFrom(foregroundColor: _successInk),
              child: const Text('Submit another'),
            ),
          ],
        );
        break;
      case _SubmitState.error:
        banner = _statusBox(
          background: const Color(0xFF2A1113),
          borderColor: const Color(0xFF5A2226),
          leading: const Icon(Icons.error_outline,
              color: Color(0xFFFF8A8A), size: 20),
          label: 'Error',
          text: "Couldn't submit your report. Check your connection and try again.",
          textColor: const Color(0xFFFFC9C9),
          actions: [
            TextButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFC9C9),
              ),
            ),
          ],
        );
        break;
      case _SubmitState.idle:
        break;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: banner ?? const SizedBox(width: double.infinity),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _type,
            decoration: _decoration('Report type'),
            items: [
              for (final t in _reportTypes)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: _loading
                ? null
                : (v) {
                    if (v != null) setState(() => _type = v);
                    _onEdited();
                  },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            focusNode: _titleFocus,
            enabled: !_loading,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Title', hint: 'e.g. Sambong shown as Lagundi'),
            validator: _validateTitle,
            onChanged: (_) => _onEdited(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _detailsController,
            enabled: !_loading,
            minLines: 4,
            maxLines: 6,
            decoration: _decoration('What went wrong?',
                hint: 'Describe the problem so we can look into it'),
            validator: _validateDetails,
            onChanged: (_) => _onEdited(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.onBrand,
                disabledBackgroundColor: AppColors.brand.withAlpha(140),
                disabledForegroundColor: AppColors.onBrand,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: _loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.onBrand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Submitting…'),
                      ],
                    )
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    if (_loadingReports) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reports.isEmpty) {
      // EMPTY: no reports yet
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 28, color: AppColors.brand),
            ),
            const SizedBox(height: 14),
            Text(
              'Empty: no reports yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Reports you submit will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _startNewReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: BorderSide(color: AppColors.brand),
              ),
              child: const Text('Create a report'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final r in _reports)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bgAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${r.id} · ${_time(r.createdAt)}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.details,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPageBody() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MicroLabel(
                  'Support channel',
                  color: AppColors.lime,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tell us what went wrong',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Wrong plant name, missing details, or an app problem.',
                  style: TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _buildStatusBanner(),
                _buildForm(),
                const SizedBox(height: 32),
                Text(
                  'My reports (${_reports.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReportsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Embedded in the persistent app shell: no separate page chrome.
    if (widget.embedded) return _buildPageBody();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Report an issue'),
      ),
      body: HerbaBackdrop(child: _buildPageBody()),
    );
  }
}