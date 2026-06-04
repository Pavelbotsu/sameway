import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/forms/app_form.dart';
import '../../core/token_storage.dart';
import '../../core/validators/validators.dart';

class AccountSecurityScreen extends StatefulWidget {
  final String? initialName;
  final String? initialEmail;
  final void Function(String name)? onNameUpdated;

  const AccountSecurityScreen({
    super.key,
    this.initialName,
    this.initialEmail,
    this.onNameUpdated,
  });

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late final TextEditingController _nameCtrl;
  final _nameFormKey = GlobalKey<FormState>();
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName(AppFormController form) async {
    if (!form.validate()) return;
    final name = TextSanitizer.sanitize(_nameCtrl.text);
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.put(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        await TokenStorage().save(
          token: jwt,
          role: (await TokenStorage().getRole()) ?? '',
          userId: (await TokenStorage().getUserId()) ?? '',
          name: name,
        );
        if (!mounted) return;
        widget.onNameUpdated?.call(name);
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.nameUpdated),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _savingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.accountSecurity),
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.initialEmail ?? '—',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (widget.initialEmail != null) {
                      Clipboard.setData(
                          ClipboardData(text: widget.initialEmail!));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l.emailCopied),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  child: const Icon(Icons.copy_rounded,
                      color: AppColors.textSecondary, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppForm(
            formKey: _nameFormKey,
            builder: (context, form) => Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.done,
                  validator: (v) => RequiredValidator.validate(v, l),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.displayName,
                    labelStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _savingName ? null : () => _saveName(form),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _savingName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text(l.save),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Divider(color: AppColors.border),
          const SizedBox(height: 20),
          Text(
            l.changePassword,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const _ChangePasswordSection(),
        ],
      ),
    );
  }
}

class _ChangePasswordSection extends StatefulWidget {
  const _ChangePasswordSection();

  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppFormController form) async {
    final l = AppLocalizations.of(context);
    setState(() => _serverError = null);
    if (!form.validate()) return;
    setState(() => _saving = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/auth/change-password'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _currentCtrl.text,
          'new_password': _newCtrl.text,
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
        form.reset();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.passwordUpdated),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final msg =
            (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed';
        setState(() => _serverError = msg);
      }
    } catch (_) {
      setState(() => _serverError = l.networkError);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputAction action = TextInputAction.next,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          obscureText: true,
          textInputAction: action,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppForm(
      formKey: _formKey,
      builder: (context, form) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _currentCtrl,
            label: l.currentPassword,
            validator: (v) => RequiredValidator.validate(v, l),
          ),
          _field(
            controller: _newCtrl,
            label: l.newPassword,
            validator: (v) => PasswordValidator.validate(v, l),
          ),
          _field(
            controller: _confirmCtrl,
            label: l.confirmNewPassword,
            action: TextInputAction.done,
            validator: (v) =>
                PasswordValidator.confirm(_newCtrl.text, v, l),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _serverError == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                    child: Text(
                      _serverError!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12),
                    ),
                  ),
          ),
          ElevatedButton(
            onPressed: _saving ? null : () => _submit(form),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text(l.updatePassword),
          ),
        ],
      ),
    );
  }
}
