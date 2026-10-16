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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // SHARED LOGIC (used by both layouts, same behaviour as before)
  // ---------------------------------------------------------------------

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = context.read<AuthState>();
      final success = await authState.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (success) {
        // Lets the browser / OS offer to save the credentials.
        TextInput.finishAutofillContext();
      } else if (mounted) {
        setState(() => _errorMessage = 'Invalid email or password');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Widget _buildErrorBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: _errorMessage == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// The form itself. Identical on web and mobile, so features stay in sync.
  Widget _buildForm({required double titleSize}) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
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
              _buildErrorBanner(),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enabled: !_isLoading,
                style: const TextStyle(color: _ink),
                cursorColor: _brandGreen,
                decoration: _fieldDecoration(
                  label: 'Email',
                  icon: Icons.email_outlined,
                ),
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
                enabled: !_isLoading,
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
                // Pressing Enter / "Done" submits, which matters on web.
                onFieldSubmitted: (_) => _handleLogin(),
                validator: _validatePassword,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
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
                onPressed: _isLoading ? null : _continueAsGuest,
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
                    onPressed: _isLoading ? null : _openRegister,
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