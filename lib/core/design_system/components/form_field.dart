import 'package:material_ui/material_ui.dart';

import '../foundations/mechi.dart';

/// A themed form field with the approved white and canvas surfaces.
class MechiFormField extends StatelessWidget {
  const MechiFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.helperMaxLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.obscureText = false,
  }) : _multiline = false;

  const MechiFormField.description({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength = 240,
  }) : obscureText = false,
       _multiline = true,
       hint = null,
       helper = null,
       helperMaxLines = null,
       keyboardType = null,
       textInputAction = null,
       validator = null,
       onSubmitted = null;

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final int? helperMaxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final bool _multiline;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    autocorrect: !obscureText,
    enableSuggestions: !obscureText,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: helperMaxLines,
      fillColor: _multiline ? Mechi.canvas : null,
      alignLabelWithHint: _multiline,
    ),
    minLines: _multiline ? 2 : null,
    maxLines: _multiline ? 4 : 1,
    maxLength: maxLength,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    validator: validator,
    onFieldSubmitted: onSubmitted,
  );
}
