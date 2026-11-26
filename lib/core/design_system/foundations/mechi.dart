import 'package:material_ui/material_ui.dart';

abstract final class Mechi {
  static const canvas = Color(0xffececf4);
  static const white = Colors.white;
  static const ink = Color(0xff14141c);
  static const muted = Color(0xff616170);
  static const line = Color(0xffe5e5ec);
  static const pale = Color(0xffe7edf3);
  static const navy = Color(0xff113155);
  static const paper = Color(0xfffaf7fb);
  static const error = Color(0xffb73646);
  static const star = Color(0xff996019);
  static const scrim = Color(0x9914141c);
  static const hero = Color(0xff22232e);
  static const grid = Color(0xffdcdad6);
  static const park = Color(0xffd3e0cb);
  static const arterial = Color(0xfff4ddb0);
  static const compactControlHeight = 44.0;
  static const controlHeight = 48.0;
  static const controlRadius = 14.0;
  static const pillRadius = 100.0;
  static const pageItemGap = 12.0;
  static const gap = 8.0;
  static const pad = 16.0;
  static const radius = 20.0;
  static const sheetRadius = 28.0;
  static const motion = Duration(milliseconds: 300);
  static const printMotion = Duration(milliseconds: 900);
  static const curve = Curves.easeOutCubic;
  static const sans = 'Inter';
  static const mono = 'IBM Plex Mono';
  static Duration animate(BuildContext context, [Duration duration = motion]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: navy, surface: white).copyWith(
      primary: navy,
      onPrimary: white,
      primaryContainer: pale,
      onPrimaryContainer: navy,
      onSurface: ink,
      error: error,
    ),
    scaffoldBackgroundColor: canvas,
    fontFamily: sans,
    textTheme: MechiTypography.textTheme.apply(
      fontFamily: sans,
      bodyColor: ink,
      displayColor: ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Approved semantic type roles applied by the app theme.
abstract final class MechiTypography {
  static const textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 13, height: 1.35),
    bodySmall: TextStyle(fontSize: 11, color: Mechi.muted),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}
