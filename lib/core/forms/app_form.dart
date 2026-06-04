import 'package:flutter/material.dart';

/// Thin convenience wrapper around [Form] that owns a [GlobalKey] and
/// exposes helpers for the most common submit-lifecycle calls. The wrapper
/// exists so each logical form surface (account, password, car, trip planner,
/// auth) can share one consistent shape without bringing in a third-party
/// form package.
///
/// Usage:
/// ```
/// AppForm(
///   builder: (context, form) => Column(children: [
///     TextFormField(validator: EmailValidator.validate),
///     ElevatedButton(onPressed: () {
///       if (form.validate()) {
///         // submit
///       }
///     }, child: const Text('Submit')),
///   ]),
/// )
/// ```
class AppForm extends StatefulWidget {
  final Widget Function(BuildContext context, AppFormController controller)
      builder;
  final GlobalKey<FormState>? formKey;
  final AutovalidateMode autovalidateMode;

  const AppForm({
    super.key,
    required this.builder,
    this.formKey,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  @override
  State<AppForm> createState() => _AppFormState();
}

class _AppFormState extends State<AppForm> {
  late final GlobalKey<FormState> _key;
  late final AppFormController _controller;

  @override
  void initState() {
    super.initState();
    _key = widget.formKey ?? GlobalKey<FormState>();
    _controller = AppFormController._(_key);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      autovalidateMode: widget.autovalidateMode,
      child: Builder(builder: (ctx) => widget.builder(ctx, _controller)),
    );
  }
}

class AppFormController {
  final GlobalKey<FormState> _key;
  AppFormController._(this._key);

  /// Runs every field's validator. Returns true when all pass.
  bool validate() => _key.currentState?.validate() ?? false;

  /// Calls onSaved on each field. Use after [validate] succeeds.
  void save() => _key.currentState?.save();

  /// Clears all fields back to their initial state.
  void reset() => _key.currentState?.reset();
}
