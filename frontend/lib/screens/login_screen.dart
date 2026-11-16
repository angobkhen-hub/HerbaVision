import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import '../theme/app_animations.dart';
import '../theme/herba_ui.dart';

// ---------------------------------------------------------------------------
// Display-only palette for this screen: a dark botanical page with a bright
// lime-to-mint login card (the same colours as the HerbaVision wordmark).
// ---------------------------------------------------------------------------
const _brandGreen = Color(0xFFC6FF4D);
const _onLime = Color(0xFF06130B);
const _ink = Color(0xFFEDF8F0);
const _muted = Color(0xFF9DB9A8);
const _fieldFill = Color(0xFF0F2017);
const _line = Color(0xFF1E3627);
const _deepGreen = Color(0xFF07130D);

/// Dark gradient shared by the whole page (brand panel and form side).
const _pageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF081810), Color(0xFF04100A), Color(0xFF0B2B1A)],
);

/// The "HerbaVision" wordmark colours, used as-is on the login card.
const _wordmarkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Colors.white, Color(0xFFD8FF7A), Color(0xFF2EE59D)],
);

/// Bright lime-to-mint card, in the same colours as the wordmark.
const _cardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF2FFC9),
    Color(0xFFD8FF7A),
    Color(0xFF62EEAB),
    Color(0xFF2EE59D),
  ],
  stops: [0.0, 0.38, 0.72, 1.0],
);

// Card (lime) text and field colours.
const _cardInk = Color(0xFF052E1B);
const _cardMuted = Color(0xFF2C5A3F);
const _cardAccent = Color(0xFF0B5D36);
const _cardFieldFill = Color(0x59FFFFFF);
const _cardFieldBorder = Color(0x40FFFFFF);
const _cardDivider = Color(0x26052E1B);
const _cardGuestBorder = Color(0x4D052E1B);
const _cardButtonBg = Color(0xFF0A3620);
const _cardButtonFg = Color(0xFFC6FF4D);

/// Colours the form needs. Mobile uses the dark set on its bottom sheet; the
/// web card uses the lime set on its bright card.
class _FormSkin {
  const _FormSkin({
    required this.ink,
    required this.muted,
    required this.fieldFill,
    required this.fieldBorder,
    required this.accent,
    required this.divider,
    required this.guestBorder,
    required this.buttonBg,
    required this.buttonFg,
    required this.successBg,
    required this.successLine,
    required this.successInk,
    required this.loadingBg,
    required this.loadingLine,
    required this.loadingInk,
    required this.errorBg,
    required this.errorLine,
    required this.errorInk,
  });

  final Color ink;
  final Color muted;
  final Color fieldFill;
  final Color fieldBorder;
  final Color accent;
  final Color divider;
  final Color guestBorder;
  final Color buttonBg;
  final Color buttonFg;
  final Color successBg;
  final Color successLine;
  final Color successInk;
  final Color loadingBg;
  final Color loadingLine;
  final Color loadingInk;
  final Color errorBg;
  final Color errorLine;
  final Color errorInk;
}

const _darkFormSkin = _FormSkin(
  ink: _ink,
  muted: _muted,
  fieldFill: _fieldFill,
  fieldBorder: Colors.transparent,
  accent: _brandGreen,
  divider: _line,
  guestBorder: Color(0xFF2A4433),
  buttonBg: _brandGreen,
  buttonFg: _onLime,
  successBg: Color(0xFF0F2C1B),
  successLine: Color(0xFF2A6B45),
  successInk: Color(0xFF9BFFC0),
  loadingBg: Color(0xFF0E2233),
  loadingLine: Color(0xFF1E4A66),
  loadingInk: Color(0xFF9BD8FF),
  errorBg: Color(0xFF2A1113),
  errorLine: Color(0xFF5A2226),
  errorInk: Color(0xFFFFC9C9),
);

const _limeFormSkin = _FormSkin(
  ink: _cardInk,
  muted: _cardMuted,
  fieldFill: _cardFieldFill,
  fieldBorder: _cardFieldBorder,
  accent: _cardAccent,
  divider: _cardDivider,
  guestBorder: _cardGuestBorder,
  buttonBg: _cardButtonBg,
  buttonFg: _cardButtonFg,
  successBg: Color(0xFFE7F7EC),
  successLine: Color(0xFFB6E3C4),
  successInk: Color(0xFF146C3C),
  loadingBg: Color(0xFFE8F2FB),
  loadingLine: Color(0xFFBBD8EE),
  loadingInk: Color(0xFF1F5B85),
  errorBg: Color(0xFFFDECEC),
  errorLine: Color(0xFFF0C2C2),
  errorInk: Color(0xFFA12828),
);

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

  // The login card swaps between "Log in" and "Create account" in place, so
  // tapping Sign up animates the form instead of opening another page.
  bool _showRegister = false;
  final _registerFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureRegisterPassword = true;
  bool _obscureConfirm = true;
  bool _registerLoading = false;
  bool _registerSlow = false;
  AutovalidateMode _registerAutovalidate = AutovalidateMode.disabled;
  AuthResult? _registerError;
  Timer? _registerSlowTimer;

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
    _registerSlowTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _nameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmController.dispose();
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

  /// Swaps the card between Log in and Create account in place.
  void _switchAuthMode(bool register) {
    if (_locked || _registerLoading || _showRegister == register) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _showRegister = register;
      _error = null;
      _registerError = null;
      _autovalidate = AutovalidateMode.disabled;
      _registerAutovalidate = AutovalidateMode.disabled;
      // Carry the email across so the user does not type it twice.
      if (register) {
        _registerEmailController.text = _emailController.text.trim();
      } else {
        _emailController.text = _registerEmailController.text.trim();
      }
    });
  }

  void _clearRegisterError() {
    if (_registerError != null) setState(() => _registerError = null);
  }

  Future<void> _handleRegister() async {
    if (_registerLoading) return; // prevents duplicate submissions

    // EMPTY / INVALID INPUT: explain what is missing, don't call the server.
    if (!_registerFormKey.currentState!.validate()) {
      setState(
        () => _registerAutovalidate = AutovalidateMode.onUserInteraction,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final authState = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    // LOADING
    _registerSlowTimer?.cancel();
    setState(() {
      _registerLoading = true;
      _registerSlow = false;
      _registerError = null;
    });
    _registerSlowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _registerLoading) {
        setState(() => _registerSlow = true);
      }
    });

    final result = await authState.register(
      name,
      _registerEmailController.text.trim(),
      _registerPasswordController.text,
    );
    _registerSlowTimer?.cancel();
    if (!mounted) return;

    // SUCCESS: AuthState is now logged in, so the app swaps to the dashboard.
    if (result.success) {
      setState(() {
        _registerLoading = false;
        _registerSlow = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Account created. Welcome, $name!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ERROR: show what went wrong and what the user can do about it.
    setState(() {
      _registerLoading = false;
      _registerSlow = false;
      _registerError = result;
    });
  }

  void _continueAsGuest() {
    context.read<AuthState>().continueAsGuest();
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
    required _FormSkin skin,
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
      labelStyle: TextStyle(color: skin.muted),
      floatingLabelStyle: TextStyle(color: skin.accent),
      prefixIcon: Icon(icon),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ? skin.accent : skin.muted,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: skin.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(skin.fieldBorder),
      enabledBorder: border(skin.fieldBorder),
      focusedBorder: border(skin.accent, 1.8),
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
  Widget _buildStatusBanner(_FormSkin skin) {
    Widget? banner;

    if (_success) {
      final name = _successName;
      banner = _statusBox(
        background: skin.successBg,
        borderColor: skin.successLine,
        leading: Icon(Icons.check_circle, color: skin.successInk, size: 20),
        label: 'Success',
        text: name == null
            ? 'Login successful. Welcome back!'
            : 'Login successful. Welcome back, $name!',
        textColor: skin.successInk,
        extra: 'Opening your dashboard…',
      );
    } else if (_isLoading) {
      banner = _statusBox(
        background: skin.loadingBg,
        borderColor: skin.loadingLine,
        leading: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: skin.loadingInk,
          ),
        ),
        label: 'Loading',
        text: 'Logging you in…',
        textColor: skin.loadingInk,
        extra:
            _slow ? 'Still working… the server is taking longer than usual.' : null,
      );
    } else if (_error != null) {
      final error = _error!;
      banner = _statusBox(
        background: skin.errorBg,
        borderColor: skin.errorLine,
        leading: Icon(Icons.error_outline, color: skin.errorInk, size: 20),
        label: 'Error',
        text: error.message,
        textColor: skin.errorInk,
        // Retry is offered only when trying again can help
        // (connection or server problems, not a wrong password).
        action: error.canRetry
            ? TextButton.icon(
                onPressed: _locked ? null : _handleLogin,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: skin.errorInk,
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

  /// The login form. Identical on web and mobile, so features stay in sync.
  Widget _buildLoginForm({
    required double titleSize,
    required _FormSkin skin,
  }) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MicroLabel('Secure access', color: skin.accent),
              const SizedBox(height: 12),
              Text(
                'Log in',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: skin.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use your account to continue.',
                style: TextStyle(fontSize: 14, color: skin.muted),
              ),
              const SizedBox(height: 24),
              _buildStatusBanner(skin),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enabled: !_locked,
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
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
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    color: skin.muted,
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
                    backgroundColor: skin.buttonBg,
                    foregroundColor: skin.buttonFg,
                    disabledBackgroundColor: skin.buttonBg.withAlpha(90),
                    disabledForegroundColor: skin.buttonFg.withAlpha(150),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: skin.buttonFg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Logging in…'),
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
              Row(
                children: [
                  Expanded(child: Divider(color: skin.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: skin.muted)),
                  ),
                  Expanded(child: Divider(color: skin.divider)),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _locked ? null : _continueAsGuest,
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as guest'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: skin.accent,
                  side: BorderSide(color: skin.guestBorder, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(color: skin.muted),
                  ),
                  TextButton(
                    onPressed: _locked ? null : () => _switchAuthMode(true),
                    style: TextButton.styleFrom(
                      foregroundColor: skin.accent,
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

  /// Shows the registration state: Loading or Error (nothing otherwise).
  Widget _buildRegisterStatusBanner(_FormSkin skin) {
    Widget? banner;

    if (_registerLoading) {
      banner = _statusBox(
        background: skin.loadingBg,
        borderColor: skin.loadingLine,
        leading: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: skin.loadingInk,
          ),
        ),
        label: 'Loading',
        text: 'Creating your account…',
        textColor: skin.loadingInk,
        extra: _registerSlow
            ? 'Still working… the server is taking longer than usual.'
            : null,
      );
    } else if (_registerError != null) {
      final error = _registerError!;
      banner = _statusBox(
        background: skin.errorBg,
        borderColor: skin.errorLine,
        leading: Icon(Icons.error_outline, color: skin.errorInk, size: 20),
        label: 'Error',
        text: error.message,
        textColor: skin.errorInk,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error.failure == AuthFailure.emailTaken)
              TextButton(
                onPressed:
                    _registerLoading ? null : () => _switchAuthMode(false),
                style: TextButton.styleFrom(foregroundColor: skin.errorInk),
                child: const Text('Log in instead'),
              ),
            if (error.canRetry)
              TextButton.icon(
                onPressed: _registerLoading ? null : _handleRegister,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: skin.errorInk),
              ),
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: banner ?? const SizedBox(width: double.infinity),
    );
  }

  /// The Create account form, using the same skin as the login card so the
  /// in-place swap looks like one continuous card.
  Widget _buildRegisterForm({
    required double titleSize,
    required _FormSkin skin,
  }) {
    return AutofillGroup(
      child: Form(
        key: _registerFormKey,
        autovalidateMode: _registerAutovalidate,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MicroLabel('New account', color: skin.accent),
              const SizedBox(height: 12),
              Text(
                'Create account',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: skin.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Save your scans and build your herb library.',
                style: TextStyle(fontSize: 14, color: skin.muted),
              ),
              const SizedBox(height: 24),
              _buildRegisterStatusBanner(skin),
              TextFormField(
                controller: _nameController,
                enabled: !_registerLoading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
                  label: 'Full name',
                  icon: Icons.person_outline,
                ),
                onChanged: (_) => _clearRegisterError(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registerEmailController,
                enabled: !_registerLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
                  label: 'Email',
                  icon: Icons.email_outlined,
                ),
                onChanged: (_) => _clearRegisterError(),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registerPasswordController,
                enabled: !_registerLoading,
                obscureText: _obscureRegisterPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    color: skin.muted,
                    tooltip: _obscureRegisterPassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(_obscureRegisterPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() =>
                        _obscureRegisterPassword = !_obscureRegisterPassword),
                  ),
                ),
                onChanged: (_) => _clearRegisterError(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                enabled: !_registerLoading,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: TextStyle(color: skin.ink),
                cursorColor: skin.accent,
                decoration: _fieldDecoration(
                  skin: skin,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    color: skin.muted,
                    tooltip:
                        _obscureConfirm ? 'Show password' : 'Hide password',
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onChanged: (_) => _clearRegisterError(),
                // Pressing Enter / "Done" submits, which matters on web.
                onFieldSubmitted: (_) => _handleRegister(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (value != _registerPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _registerLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: skin.buttonBg,
                    foregroundColor: skin.buttonFg,
                    disabledBackgroundColor: skin.buttonBg.withAlpha(90),
                    disabledForegroundColor: skin.buttonFg.withAlpha(150),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _registerLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: skin.buttonFg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Creating account…'),
                          ],
                        )
                      : const Text('Create account'),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: skin.muted),
                  ),
                  TextButton(
                    onPressed: _registerLoading
                        ? null
                        : () => _switchAuthMode(false),
                    style: TextButton.styleFrom(
                      foregroundColor: skin.accent,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Slides and fades between Log in and Create account inside the same card.
  Widget _buildAuthForms({
    required double titleSize,
    required _FormSkin skin,
  }) {
    final showRegister = _showRegister;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey<bool>(showRegister);
          final begin =
              incoming ? const Offset(0.07, 0) : const Offset(-0.07, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          );
        },
        child: showRegister
            ? KeyedSubtree(
                key: const ValueKey<bool>(true),
                child: _buildRegisterForm(titleSize: titleSize, skin: skin),
              )
            : KeyedSubtree(
                key: const ValueKey<bool>(false),
                child: _buildLoginForm(titleSize: titleSize, skin: skin),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT: brand header on top, form in a bottom sheet
  // ---------------------------------------------------------------------

  Widget _buildMobileHeader() {
    return const Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _VeinPainter(color: Colors.white)),
        ),
        Positioned.fill(
          child: AnimatedLeafField(
            leafColor: Colors.white,
            blobColor: Color(0xFF6FCB94),
            intensity: 0.55,
            showBlobs: false,
          ),
        ),
        Positioned(
          right: -46,
          top: 6,
          child: Opacity(
            opacity: 0.5,
            child: ScanReticle(size: 210, color: Color(0xFF2EE59D)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(28, 36, 28, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                beginScale: 0.8,
                child: _LogoBadge(size: 56),
              ),
              SizedBox(height: 20),
              FadeSlideIn(
                delay: Duration(milliseconds: 110),
                child: GradientText(
                  'HerbaVision',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                  gradient: _wordmarkGradient,
                ),
              ),
              SizedBox(height: 8),
              FadeSlideIn(
                delay: Duration(milliseconds: 200),
                child: Text(
                  'Identify herbal plants with confidence',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14.5,
                    height: 1.4,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ),
              SizedBox(height: 14),
              FadeSlideIn(
                delay: Duration(milliseconds: 280),
                child: HerbaPill('Vision core online'),
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _pageGradient),
        child: SafeArea(
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
                              color: Color(0xFF0B1510),
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(32)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 40,
                                  offset: Offset(0, -12),
                                ),
                              ],
                            ),
                            padding:
                                EdgeInsets.fromLTRB(24, 32, 24, 24 + bottomInset),
                            // The register form is taller than the login form,
                            // so the sheet scrolls instead of overflowing.
                            child: SingleChildScrollView(
                              child: _buildAuthForms(
                                titleSize: 25,
                                skin: _darkFormSkin,
                              ),
                            ),
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
      ),
    );
  }

  // ---------------------------------------------------------------------
  // WEB LAYOUT: brand panel on the left, login card on the right
  // ---------------------------------------------------------------------

  Widget _buildBrandPanel({required bool compact}) {
    return Padding(
      // A little more breathing room on the left so the copy does not sit
      // right against the edge of the screen.
      padding: EdgeInsets.fromLTRB(
        compact ? 72 : 96,
        56,
        compact ? 40 : 56,
        56,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FadeSlideIn(
                beginScale: 0.85,
                child: _LogoBadge(size: 64),
              ),
              const SizedBox(height: 28),
              const FadeSlideIn(
                delay: Duration(milliseconds: 90),
                child: MicroLabel(
                  'Botanical intelligence system',
                  color: _brandGreen,
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: GradientText(
                  'HerbaVision',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: compact ? 42 : 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    height: 1.02,
                  ),
                  gradient: _wordmarkGradient,
                ),
              ),
              const SizedBox(height: 14),
              const FadeSlideIn(
                delay: Duration(milliseconds: 210),
                child: Text(
                  'Identify herbal plants with confidence.',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 17,
                    height: 1.5,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const FadeSlideIn(
                delay: Duration(milliseconds: 250),
                child: Text(
                  'HerbaVision is an AI-assisted identification system for '
                  'herbal and medicinal plants. It reads a single photo, '
                  'matches it against a botanical database, and returns the '
                  'name, details, and a place to keep everything you find.',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14.5,
                    height: 1.6,
                    color: Color(0xA6FFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const FadeSlideIn(
                delay: Duration(milliseconds: 280),
                child: HerbaPill('Vision core online'),
              ),
              const SizedBox(height: 30),
              const FadeSlideIn(
                delay: Duration(milliseconds: 320),
                child: MicroLabel(
                  'System capabilities',
                  color: Color(0x8CFFFFFF),
                ),
              ),
              const SizedBox(height: 18),
              const FadeSlideIn(
                delay: Duration(milliseconds: 360),
                child: _FeatureRow(
                  icon: Icons.photo_camera_outlined,
                  text: 'Take or upload a photo of a plant',
                ),
              ),
              const SizedBox(height: 16),
              const FadeSlideIn(
                delay: Duration(milliseconds: 420),
                child: _FeatureRow(
                  icon: Icons.eco_outlined,
                  text: 'See its name and details in seconds',
                ),
              ),
              const SizedBox(height: 16),
              const FadeSlideIn(
                delay: Duration(milliseconds: 480),
                child: _FeatureRow(
                  icon: Icons.bookmark_border,
                  text: 'Keep the plants you identify in one place',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeb() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1120;

    return Scaffold(
      backgroundColor: _deepGreen,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _pageGradient),
        child: Stack(
          children: [
            // One continuous botanical backdrop behind both sides.
            const Positioned.fill(
              child: CustomPaint(painter: _VeinPainter(color: Colors.white)),
            ),
            const Positioned.fill(
              child: AnimatedLeafField(
                leafColor: Colors.white,
                blobColor: Color(0xFF6FCB94),
                intensity: 0.55,
                showBlobs: false,
              ),
            ),
            const Positioned(
              right: -150,
              bottom: -160,
              child: Opacity(
                opacity: 0.35,
                child: ScanReticle(size: 520, color: Color(0xFF2EE59D)),
              ),
            ),
            const Positioned(
              left: -200,
              top: -180,
              child: Opacity(
                opacity: 0.2,
                child: ScanReticle(size: 480, color: Color(0xFF6FCB94)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: compact ? 5 : 6,
                  child: _buildBrandPanel(compact: compact),
                ),
                Expanded(
                  flex: compact ? 5 : 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
                          decoration: BoxDecoration(
                            gradient: _cardGradient,
                            borderRadius: BorderRadius.circular(26),
                            border:
                                Border.all(color: const Color(0x59FFFFFF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x73000000),
                                blurRadius: 50,
                                offset: Offset(0, 22),
                              ),
                              BoxShadow(
                                color: Color(0x4D2EE59D),
                                blurRadius: 64,
                                spreadRadius: -14,
                              ),
                            ],
                          ),
                          child: _buildAuthForms(
                            titleSize: 28,
                            skin: _limeFormSkin,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return HerbaLogo(size: size);
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withAlpha(24)),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFC6FF4D)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              height: 1.45,
              color: Colors.white.withAlpha(210),
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
  const _VeinPainter({required this.color});

  final Color color;

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
      ..color = color.withAlpha(46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final vein = Paint()
      ..color = color.withAlpha(32)
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
  bool shouldRepaint(covariant _VeinPainter oldDelegate) =>
      oldDelegate.color != color;
}