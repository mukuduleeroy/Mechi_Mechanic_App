import 'package:material_ui/material_ui.dart';
import 'assets.dart';

class MechiLogo extends StatelessWidget {
  const MechiLogo({super.key, required this.height, this.symbolOnly = false});
  final double height;
  final bool symbolOnly;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      symbolOnly ? MechiAssets.symbol : MechiAssets.logo,
      height: height,
      fit: BoxFit.contain,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      semanticLabel: symbolOnly ? null : 'Mechi',
      excludeFromSemantics: symbolOnly,
    );
  }
}
