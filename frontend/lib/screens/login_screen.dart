import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import 'register_screen.dart';

// ---------------------------------------------------------------------------
// Display-only palette for this screen.
// ---------------------------------------------------------------------------
const _brandGreen = Color(0xFF2F7A4F);
const _deepGreen = Color(0xFF1E5A3A);
const _ink = Color(0xFF1D2B23);
const _muted = Color(0xFF66766B);
const _fieldFill = Color(0xFFF1F5F2);
const _line = Color(0xFFDDE5DF);
const _pageTint = Color(0xFFF6F9F7);

// Status banners (Loading = blue, Success = green, Error = red).
const _loadingInk = Color(0xFF1F5A99);
const _loadingBg = Color(0xFFEAF2FB);
const _loadingLine = Color(0xFFB9D3EE);
const _successBg = Color(0xFFE8F4EC);
const _successLine = Color(0xFFB7D9C4);

/// How long the "Login successful" message stays on screen before the
/// dashboard opens.
const Duration _kSuccessHold = Duration(seconds: 2);

/// Screens at least this wide get the split-screen "web" layout.
/// Anything narrower gets the mobile layout.
const double _kWideBreakpoint = 900;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // The async states of this screen:
  //   LOADING : _isLoading (+ _slow when it takes longer than usual)
  //   SUCCESS : _success, "Login successful" shows, then the app moves on
  //   EMPTY   : a field is blank or invalid, so the form explains what is missing
  //   ERROR   : _error holds what went wrong and what the user can do next
  bool _isLoading = false;
  bool _slow = false;
  bool _success = false;
  String? _successName;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  AuthResult? _error;
  Timer? _slowTimer;

  /// True while a request is running or the success message is showing, so
  /// nothing can be submitted twice.
  bool get _locked => _isLoading || _success;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // SHARED LOGIC (used by both layouts)
  // ---------------------------------------------------------------------

  void _startLoading() {
    _slowTimer?.cancel();
    setState(() {
      _isLoading = true;
      _slow = false;
      _error = null;
    });
    // After a few seconds, tell the user we are still working.
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isLoading) setState(() => _slow = true);
    });
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _handleLogin() async {
    if (_locked) return; // prevents duplicate submissions

    // EMPTY / INVALID INPUT: explain what is missing, don't call the server.
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    FocusScope.of(context).unfocus();
    final authState = context.read<AuthState>();

    // LOADING
    _startLoading();
    final result = await authState.login(
      _emailController.text.trim(),
      _passwordController.text,
      startSession: false, // hold the session so the success message can show
    );
    _slowTimer?.cancel();
    if (!mounted) return;

    // SUCCESS: show the message, then let the app move to the dashboard.
    if (result.success) {
      // Lets the browser / OS offer to save the credentials.
      TextInput.finishAutofillContext();
      setState(() {
        _isLoading = false;
        _slow = false;
        _success = true;
        _successName = authState.pendingUserName;
      });
      await Future.delayed(_kSuccessHold);
      authState.completeLogin();
      return;
    }

    // ERROR: show what went wrong and what the user can do about it.
    setState(() {
      _isLoading = false;
      _slow = false;
      _error = result;
    });
  }

  void _continueAsGuest() {
    context.read<AuthState>().continueAsGuest();
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    if (!RegExp(r'^[\w.\-]+@[\w\-]+\.\w+$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ---------------------------------------------------------------------
  // SHARED DISPLAY PIECES
  // ---------------------------------------------------------------------

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      floatingLabelStyle: const TextStyle(color: _brandGreen),
      prefixIcon: Icon(icon),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused) ? _brandGreen : _muted,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(_brandGreen, 1.8),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400, 1.8),
    );
  }

  /// One status box: used for Loading, Success and Error so they look alike.
  Widget _statusBox({
    required Color background,
    required Color borderColor,
    required Widget leading,
    required String label,
    required String text,
    required Color textColor,
    String? extra,
    Widget? action,
  }) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  padding: const EdgeInsets.only(top: 1),
                  child: leading,
                ),
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
                child: Text(
                  extra,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
            if (action != null) Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }

  /// Shows the current state: Loading, Success or Error (nothing otherwise).
  Widget _buildStatusBanner() {
    Widget? banner;

    if (_success) {
      final name = _successName;
      banner = _statusBox(
        background: _successBg,
        borderColor: _successLine,
        leading: const Icon(Icons.check_circle, color: _brandGreen, size: 20),
        label: 'Success',
        text: name == null
            ? 'Login successful. Welcome back!'
            : 'Login successful. Welcome back, $name!',
        textColor: _deepGreen,
        extra: 'Opening your dashboard…',
      );
    } else if (_isLoading) {
      banner = _statusBox(
        background: _loadingBg,
        borderColor: _loadingLine,
        leading: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: _loadingInk),
        ),
        label: 'Loading',
        text: 'Logging you in…',
        textColor: _loadingInk,
        extra:
            _slow ? 'Still working… the server is taking longer than usual.' : null,
      );
    } else if (_error != null) {
      final error = _error!;
      banner = _statusBox(
        background: Colors.red.shade50,
        borderColor: Colors.red.shade200,
        leading: Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
        label: 'Error',
        text: error.message,
        textColor: Colors.red.shade800,
        // Retry is offered only when trying again can help
        // (connection or server problems, not a wrong password).
        action: error.canRetry
            ? TextButton.icon(
                onPressed: _locked ? null : _handleLogin,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
              )
            : null,
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: banner ?? const SizedBox(width: double.infinity),
    );
  }

  /// The form itself. Identical on web and mobile, so features stay in sync.
  Widget _buildForm({required double titleSize}) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log in',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use your account to continue.',
                style: TextStyle(fontSize: 14, color: _muted),
              ),
              const SizedBox(height: 24),
              _buildStatusBanner(),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enabled: !_locked,
                style: const TextStyle(color: _ink),
                cursorColor: _brandGreen,
                decoration: _fieldDecoration(
                  label: 'Email',
                  icon: Icons.email_outlined,
                ),
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_locked,
                style: const TextStyle(color: _ink),
                cursorColor: _brandGreen,
                decoration: _fieldDecoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    color: _muted,
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onChanged: (_) => _clearError(),
                // Pressing Enter / "Done" submits, which matters on web.
                onFieldSubmitted: (_) => _handleLogin(),
                validator: _validatePassword,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _locked ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _brandGreen.withAlpha(140),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Logging in…'),
                          ],
                        )
                      : _success
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 22),
                                SizedBox(width: 10),
                                Text('Logged in'),
                              ],
                            )
                          : const Text('Log in'),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider(color: _line)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: _muted)),
                  ),
                  Expanded(child: Divider(color: _line)),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _locked ? null : _continueAsGuest,
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as guest'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: _brandGreen,
                  side: const BorderSide(color: Color(0xFFBFD3C7), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: _muted),
                  ),
                  TextButton(
                    onPressed: _locked ? null : _openRegister,
                    style: TextButton.styleFrom(
                      foregroundColor: _brandGreen,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Sign up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT: brand header on top, form in a bottom sheet
  // ---------------------------------------------------------------------

  Widget _buildMobileHeader() {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _VeinPainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LogoBadge(size: 56),
              const SizedBox(height: 20),
              const Text(
                'HerbaVision',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Identify herbal plants with confidence',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.white.withAlpha(204),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _deepGreen,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            // Keeps tablets in portrait from stretching the form too wide.
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMobileHeader(),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          padding:
                              EdgeInsets.fromLTRB(24, 32, 24, 24 + bottomInset),
                          child: _buildForm(titleSize: 24),
                        ),
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

  // ---------------------------------------------------------------------
  // WEB LAYOUT: split screen, brand panel on the left, form card on the right
  // ---------------------------------------------------------------------

  Widget _buildBrandPanel({required bool compact}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepGreen, Color(0xFF184A30)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _VeinPainter())),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 48 : 72,
              vertical: 56,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LogoBadge(size: 64),
                    const SizedBox(height: 28),
                    Text(
                      'HerbaVision',
                      style: TextStyle(
                        fontSize: compact ? 40 : 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        height: 1.05,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Identify herbal plants with confidence.',
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.45,
                        color: Colors.white.withAlpha(214),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const _FeatureRow(
                      icon: Icons.photo_camera_outlined,
                      text: 'Take or upload a photo of a plant',
                    ),
                    const SizedBox(height: 18),
                    const _FeatureRow(
                      icon: Icons.eco_outlined,
                      text: 'See its name and details in seconds',
                    ),
                    const SizedBox(height: 18),
                    const _FeatureRow(
                      icon: Icons.bookmark_border,
                      text: 'Keep the plants you identify in one place',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeb() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1100;

    return Scaffold(
      backgroundColor: _pageTint,
      body: Row(
        children: [
          Expanded(flex: compact ? 5 : 6, child: _buildBrandPanel(compact: compact)),
          Expanded(
            flex: compact ? 5 : 5,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x141D2B23),
                          blurRadius: 40,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: _buildForm(titleSize: 28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BUILD: picks the layout from the available width
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;
        return isWide ? _buildWeb() : _buildMobile();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Small display widgets
// ---------------------------------------------------------------------------

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(Icons.eco, size: size * 0.57, color: Colors.white),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Colors.white.withAlpha(224),
            ),
          ),
        ),
      ],
    );
  }
}

/// Faint leaf-vein pattern drawn behind the brand area. Purely decorative.
/// Scales with whatever space it is given, so it works in the short mobile
/// header and the tall web panel.
class _VeinPainter extends CustomPainter {
  const _VeinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 1.02, size.height * 1.05);
    final control = Offset(size.width * 0.86, size.height * 0.30);
    final end = Offset(size.width * 0.34, -size.height * 0.05);

    Offset pointAt(double t) {
      final u = 1 - t;
      return start * (u * u) + control * (2 * u * t) + end * (t * t);
    }

    Offset tangentAt(double t) {
      final raw = (control - start) * (2 * (1 - t)) + (end - control) * (2 * t);
      return raw / raw.distance;
    }

    Offset rotate(Offset v, double angle) {
      final c = math.cos(angle);
      final s = math.sin(angle);
      return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    }

    final midrib = Paint()
      ..color = const Color(0x24FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final vein = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(path, midrib);

    const angle = 0.95; // about 55 degrees off the midrib
    // Cap vein length so it doesn't get huge on a wide, short panel.
    final veinBase = math.min(size.width, size.height * 1.2) * 0.34;
    for (double t = 0.12; t < 0.9; t += 0.11) {
      final p = pointAt(t);
      final dir = tangentAt(t);
      final length = veinBase * (1 - t * 0.55);
      canvas.drawLine(p, p + rotate(dir, angle) * length, vein);
      canvas.drawLine(p, p + rotate(dir, -angle) * length, vein);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}