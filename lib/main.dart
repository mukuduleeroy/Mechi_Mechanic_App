import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/mechi_app.dart';
import 'features/garage/garage_state.dart';
import 'features/account/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final MechiApi? api;
  try {
    api = await BackendConfiguration.current.initialize();
  } catch (_) {
    runApp(const MechiConfigurationUnavailable());
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        apiProvider.overrideWithValue(api),
      ],
      child: const MechiApp(),
    ),
  );
}
