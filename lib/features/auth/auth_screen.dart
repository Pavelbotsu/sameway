import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import 'auth_provider.dart';
import '../driver/driver_home_screen.dart';
import '../passenger/passenger_home_screen.dart';

class AuthScreen extends StatefulWidget {
  final String role;
  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AnimationController _anim;
  late Animation<double> _fade;

  bool get _isDriver => widget.role == 'driver';
  Color get _roleColor => _isDriver ? AppColors.primary : AppColors.teal;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final ok = _isLogin
        ? await auth.login(
            email: _email.text.trim(),
            password: _password.text,
          )
        : await auth.register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: widget.role,
          );
    if (ok && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => _isDriver
              ? const DriverHomeScreen()
              : const PassengerHomeScreen(),
        ),
        (_) => false,
      );
    }
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
    context.read<AuthProvider>().clearError();
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(),
                const SizedBox(height: 32),
                _RoleBadge(role: widget.role, color: _roleColor),
                const SizedBox(height: 16),
                Text(
                  _isLogin ? 'Welcome back' : 'Create account',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _isLogin
                      ? 'Sign in to continue your journey'
                      : 'Join sameway today',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!_isLogin) ...[
                        _Field(
                          controller: _name,
                          hint: 'Full name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) =>
                              (v?.isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _Field(
                        controller: _email,
                        hint: 'Email address',
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress,
                        validator: (v) =>
                            (v?.contains('@') ?? false) ? null : 'Invalid email',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _password,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        validator: (v) =>
                            (v?.length ?? 0) >= 6 ? null : 'Min 6 characters',
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => Column(
                    children: [
                      if (auth.status == AuthStatus.error &&
                          auth.error != null)
                        _ErrorBanner(message: auth.error!),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: auth.status == AuthStatus.loading
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _roleColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: auth.status == AuthStatus.loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? "Don't have an account? "
                          : 'Already have an account? ',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleMode,
                      child: Text(
                        _isLogin ? 'Sign Up' : 'Sign In',
                        style: TextStyle(
                          color: _roleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 17,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final Color color;
  const _RoleBadge({required this.role, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDriver = role == 'driver';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDriver ? Icons.drive_eta_rounded : Icons.person_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isDriver ? 'Driver' : 'Passenger',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? type;
  final bool obscure;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.type,
    this.obscure = false,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
