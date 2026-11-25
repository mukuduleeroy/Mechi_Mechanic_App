import 'package:material_ui/material_ui.dart';

class MechiLogo extends StatelessWidget {
  const MechiLogo({super.key, required this.height, this.symbolOnly = false});
  final double height;
  final bool symbolOnly;

  @override
  Widget build(BuildContext context) {
    final name = symbolOnly ? 'mark' : 'lockup';
    return Image.asset(
      'assets/branding/mechi-$name.png',
      height: height,
      fit: BoxFit.contain,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      semanticLabel: symbolOnly ? null : 'Mechi',
      excludeFromSemantics: symbolOnly,
    );
  }
}
