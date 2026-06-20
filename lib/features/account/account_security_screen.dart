import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/forms/app_form.dart';
import '../../core/token_storage.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/branded_snack_bar.dart';
import '../../core/widgets/user_avatar.dart';

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

  // Phase 1.3: profile photo upload. We hydrate `_photoUrl` from GET /profile
  // on entry; on upload we PUT a new URL through the existing update endpoint
  // and update the local state optimistically.
  String? _photoUrl;
  bool _uploadingPhoto = false;

  // Phase 3.3: bio + phone + email verification. Hydrated from GET /profile.
  final TextEditingController _bioCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _savingExtras = false;
  bool _emailVerified = false;
  bool _verified = false;
  bool _sendingVerifyCode = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _hydrateProfile();
  }

  Future<void> _hydrateProfile() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (!mounted || resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = (data['photo_url'] as String?)?.trim();
      setState(() {
        if (url != null && url.isNotEmpty) _photoUrl = url;
        _bioCtrl.text = (data['bio'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';
        _emailVerified = data['email_verified_at'] != null;
        _verified = data['verified'] == true;
      });
    } catch (_) {/* silent — initials fallback */}
  }

  // Phase 3.3: persist bio + phone in one call. Server truncates bio to 160
  // and phone to 32 chars; we don't double-validate here.
  Future<void> _saveExtras() async {
    final l = AppLocalizations.of(context);
    setState(() => _savingExtras = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.put(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bio': _bioCtrl.text,
          'phone': _phoneCtrl.text,
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        BrandedSnack.showSuccess(context, l.profileUpdated);
      }
    } catch (e) {
      if (mounted) BrandedSnack.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _savingExtras = false);
    }
  }

  Future<void> _requestEmailVerify() async {
    final l = AppLocalizations.of(context);
    setState(() => _sendingVerifyCode = true);
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/auth/email-verify/request'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        BrandedSnack.showInfo(context, l.verificationCodeSent);
        _showVerifyCodeSheet();
      } else {
        final msg =
            (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed';
        BrandedSnack.showError(context, msg);
      }
    } catch (e) {
      if (mounted) BrandedSnack.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _sendingVerifyCode = false);
    }
  }

  void _showVerifyCodeSheet() {
    final l = AppLocalizations.of(context);
    final codeCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _VerifyEmailSheet(
          codeCtrl: codeCtrl,
          l: l,
          onVerified: () {
            if (!mounted) return;
            setState(() => _emailVerified = true);
          },
          onResend: _requestEmailVerify,
        ),
      ),
    );
  }

  // Five weighted contributions equal to 20% each: name, photo, bio, phone,
  // verified email. The verified-identity badge is not counted (it's an
  // operator-flipped flag, not user-fillable).
  double get _completionRatio {
    int filled = 0;
    if ((_nameCtrl.text.trim()).isNotEmpty) filled++;
    if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) filled++;
    if (_bioCtrl.text.trim().isNotEmpty) filled++;
    if (_phoneCtrl.text.trim().isNotEmpty) filled++;
    if (_emailVerified) filled++;
    return filled / 5.0;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _uploadingPhoto = true);
      final userId = await TokenStorage().getUserId();
      if (userId == null) return;
      final ref = FirebaseStorage.instance
          .ref('user_photos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await _saveProfilePhoto(url);
      if (!mounted) return;
      setState(() => _photoUrl = url);
      BrandedSnack.showSuccess(
          context, AppLocalizations.of(context).photoUpdated);
    } catch (e) {
      if (mounted) BrandedSnack.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    Navigator.pop(context);
    setState(() => _uploadingPhoto = true);
    try {
      await _saveProfilePhoto('');
      if (!mounted) return;
      setState(() => _photoUrl = null);
    } catch (e) {
      if (mounted) BrandedSnack.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfilePhoto(String url) async {
    final jwt = await TokenStorage().getToken();
    if (jwt == null) return;
    await http.put(
      Uri.parse('$kApiBase/auth/profile'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'photo_url': url}),
    );
  }

  void _showPhotoSheet() {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.textPrimary),
              title: Text(l.takePhoto,
                  style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.textPrimary),
              title: Text(l.fromGallery,
                  style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: Text(l.removePhoto,
                    style: const TextStyle(color: AppColors.error)),
                onTap: _removePhoto,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
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
          // Phase 3.3 completion meter — % of fillable profile fields.
          _CompletionMeter(ratio: _completionRatio, label: l.profileCompletion),
          const SizedBox(height: 20),
          // Profile photo (Phase 1.3) — tap avatar to open camera / gallery
          // / remove sheet. Spinner overlays the avatar while uploading.
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _showPhotoSheet,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  UserAvatar(
                    photoUrl: _photoUrl,
                    name: widget.initialName,
                    size: 96,
                    verified: _verified,
                  ),
                  if (_uploadingPhoto)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  else
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.background, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l.profilePhoto,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          // Phase 3.3: email verification row + Bio + Phone editors.
          _EmailVerifyRow(
            verified: _emailVerified,
            busy: _sendingVerifyCode,
            onVerify: _requestEmailVerify,
            label: _emailVerified ? l.emailVerified : l.verifyEmail,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            maxLines: 2,
            maxLength: 160,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: l.bio,
              hintText: l.bioHint,
              labelStyle:
                  const TextStyle(color: AppColors.textSecondary),
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: l.phone,
              hintText: l.phoneHint,
              labelStyle:
                  const TextStyle(color: AppColors.textSecondary),
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
            onPressed: _savingExtras ? null : _saveExtras,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _savingExtras
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text(l.save),
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

/// Phase 3.3 horizontal progress meter at the top of the account screen.
/// Reads as 0–100 % with a teal accent track on a darker rail.
class _CompletionMeter extends StatelessWidget {
  final double ratio;
  final String label;
  const _CompletionMeter({required this.ratio, required this.label});

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phase 3.3 email-verification row. Two states:
///   - Unverified: "Verify email" CTA on the right.
///   - Verified:   green check, no CTA.
class _EmailVerifyRow extends StatelessWidget {
  final bool verified;
  final bool busy;
  final VoidCallback onVerify;
  final String label;
  const _EmailVerifyRow({
    required this.verified,
    required this.busy,
    required this.onVerify,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : Icons.mark_email_unread_outlined,
            color: verified ? AppColors.success : AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: verified ? AppColors.success : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!verified)
            TextButton(
              onPressed: busy ? null : onVerify,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.teal),
                    )
                  : Text(AppLocalizations.of(context).verifyAction),
            ),
        ],
      ),
    );
  }
}

/// Phase 3.3 modal sheet — collects the 6-digit verification code, POSTs
/// to /auth/email-verify/confirm, and pops on success.
class _VerifyEmailSheet extends StatefulWidget {
  final TextEditingController codeCtrl;
  final AppLocalizations l;
  final VoidCallback onVerified;
  final VoidCallback onResend;
  const _VerifyEmailSheet({
    required this.codeCtrl,
    required this.l,
    required this.onVerified,
    required this.onResend,
  });

  @override
  State<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends State<_VerifyEmailSheet> {
  bool _busy = false;
  String? _err;

  Future<void> _submit() async {
    final code = widget.codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _err = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/auth/email-verify/confirm'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        widget.onVerified();
        Navigator.pop(context);
        BrandedSnack.showSuccess(context, widget.l.emailVerified);
      } else {
        final msg =
            (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed';
        setState(() => _err = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.l.enterVerificationCode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.codeCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Text(
              _err!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Text(widget.l.verifyAction),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : widget.onResend,
            child: Text(
              widget.l.resendCode,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
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
    // Client-side guard so the user sees the rejection without a server
    // round-trip. The backend also enforces this — both layers required.
    if (_currentCtrl.text == _newCtrl.text) {
      setState(() => _serverError = l.passwordSameAsCurrent);
      return;
    }
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
