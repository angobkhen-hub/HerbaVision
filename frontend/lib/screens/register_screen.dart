import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // The four async states of this screen:
  //   LOADING : _isLoading (+ _slow when it takes longer than usual)
  //   SUCCESS : register() succeeded, a welcome message shows and the app moves on
  //   EMPTY   : a field is blank or invalid, so the form explains what is missing
  //   ERROR   : _error holds what went wrong and what the user can do next
  bool _isLoading = false;
  bool _slow = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  AuthResult? _error;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

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

  void _stopLoading() {
    _slowTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _slow = false;
      });
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return; // prevents duplicate submissions

    // EMPTY / INVALID INPUT: explain what is missing, don't call the server.
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    FocusScope.of(context).unfocus();
    final authState = context.read<AuthState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();

    // LOADING
    _startLoading();
    final result = await authState.register(
      name,
      _emailController.text.trim(),
      _passwordController.text,
    );

    // SUCCESS: AuthState is now logged in. Go back to the root so the app
    // shows the dashboard (the same routing as before).
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Account created. Welcome, $name!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _stopLoading();
      if (mounted) navigator.popUntil((route) => route.isFirst);
      return;
    }

    // ERROR: show what went wrong and what the user can do about it.
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _slow = false;
      _error = result;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    if (!RegExp(r'^[\w.\-]+@[\w\-]+\.\w+$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  Widget _buildErrorBanner() {
    final error = _error;
    if (error == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error.message,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
            // The next step depends on what went wrong.
            if (error.failure == AuthFailure.emailTaken)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                  ),
                  child: const Text('Log in instead'),
                ),
              ),
            if (error.canRetry)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _handleRegister,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildErrorBanner(),

                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _clearError(),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _clearError(),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      onChanged: (_) => _clearError(),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter a password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmController,
                      enabled: !_isLoading,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      onChanged: (_) => _clearError(),
                      // Pressing Enter / "Done" submits, which matters on web.
                      onFieldSubmitted: (_) => _handleRegister(),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F7A4F),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF2F7A4F).withAlpha(140),
                          disabledForegroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating account…'),
                                ],
                              )
                            : const Text('Create Account'),
                      ),
                    ),

                    // LOADING context: tell the user we are still working.
                    if (_isLoading && _slow)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Still working… the server is taking longer than usual.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF66766B)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}