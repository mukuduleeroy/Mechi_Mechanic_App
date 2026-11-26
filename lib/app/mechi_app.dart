import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_system/design_system.dart';
import '../features/assistance/request_screens.dart';
import '../features/assistance/job_screens.dart';
import '../features/garage/garage_screens.dart';
import '../features/assistance/domain.dart';

import 'design_system_gallery.dart';

class MechiApp extends ConsumerStatefulWidget {
  const MechiApp({super.key});
  @override
  ConsumerState<MechiApp> createState() => _MechiAppState();
}

class _MechiAppState extends ConsumerState<MechiApp> {
  late final GoRouter router = GoRouter(
    routes: [
      _route('/', (_, _) => const HomeScreen()),
      _route('/garage', (_, _) => const GarageScreen()),
      _route('/history', (_, _) => const HistoryScreen()),
      _route('/profile', (_, _) => const ProfileScreen()),
      _route(
        '/request',
        (_, s) => RequestScreen(
          initial: s.uri.queryParameters['service'] == 'home'
              ? Service.home
              : Service.roadside,
        ),
      ),
      _route(
        '/discover/:id',
        (_, s) => DiscoveryScreen(id: s.pathParameters['id']!),
      ),
      _route(
        '/mechanic/:id/:mechanic',
        (_, s) => MechanicScreen(
          id: s.pathParameters['id']!,
          mechanicId: int.parse(s.pathParameters['mechanic']!),
        ),
      ),
      _route('/job/:id', (_, s) => JobScreen(id: s.pathParameters['id']!)),
      _route(
        '/receipt/:id',
        (_, s) => ReceiptScreen(id: s.pathParameters['id']!),
      ),
      _route(
        '/review/:id',
        (_, s) => ReviewScreen(id: s.pathParameters['id']!),
      ),
      if (kDebugMode) _route('/gallery', (_, _) => const GalleryScreen()),
    ],
  );

  GoRoute _route(
    String path,
    Widget Function(BuildContext, GoRouterState) builder,
  ) => GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: builder(context, state),
      transitionDuration: Mechi.animate(context),
      reverseTransitionDuration: Mechi.animate(context),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Mechi',
    theme: Mechi.theme,
    routerConfig: router,
    debugShowCheckedModeBanner: false,
  );
}
