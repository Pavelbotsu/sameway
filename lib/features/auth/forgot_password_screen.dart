import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';
import '../driver/driver_home_screen.dart';
import '../passenger/passenger_home_screen.dart';
import 'auth_repository.dart';

/// Two-step password reset:
///   1. Enter email → backend emails a 6-digit code.
///   2. Enter code + new password → backend returns a fresh JWT and we
///      auto-sign the user in, then route to their home based on role.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  int _step = 0; // 0 = email, 1 = code + new password
  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppLocalizations.of(context).invalidEmail);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = AuthRepository(ApiClient(TokenStorage()));
      await repo.requestPasswordReset(email);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l.resetCodeSent),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() => _step = 1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmReset() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text;
    final l = AppLocalizations.of(context);
    if (code.length != 6) {
      setState(() => _error = l.invalidCode);
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = l.passwordTooShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final repo = AuthRepository(ApiClient(TokenStorage()));
      final result = await repo.resetPassword(
        email: email,
        code: code,
        newPassword: pw,
      );
      await TokenStorage().save(
        token: result.token,
        role: result.role,
        userId: result.userId,
        name: result.name,
        email: result.email,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l.resetSuccess),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => result.role == 'driver'
              ? const DriverHomeScreen()
              : const PassengerHomeScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l.invalidCode);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(l.forgotPassword,
            style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _step == 0 ? l.forgotPasswordHint : l.resetCodeHint,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_step == 0)
                _Field(
                  controller: _emailCtrl,
                  hint: l.emailAddress,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                )
              else ...[
                _Field(
                  controller: _codeCtrl,
                  hint: l.resetCodeHint,
                  icon: Icons.key_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _pwCtrl,
                  hint: l.newPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    tooltip: l.togglePasswordVisibility,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : (_step == 0 ? _requestCode : _confirmReset),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.black,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _step == 0 ? l.submit : l.resetSubmit,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? suffix;
  final List<String>? autofillHints;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.maxLength,
    this.suffix,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      autofillHints: autofillHints,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
