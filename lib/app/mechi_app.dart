import '../features/marketplace/assignment_screens.dart';
import '../features/marketplace/driver_marketplace_screens.dart';
import '../features/mechanic/mechanic_screen.dart' as mechanic_workspace;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_system/design_system.dart';
import '../features/assistance/request_screens.dart';
import '../features/assistance/job_screens.dart';
import '../features/garage/garage_screens.dart';
import '../features/assistance/domain.dart';
import '../features/account/backend.dart';
import '../features/account/session.dart';
import '../features/account/account_screen.dart';
import '../features/account/connected_profile.dart';

import 'design_system_gallery.dart';

class MechiApp extends ConsumerStatefulWidget {
  const MechiApp({super.key});
  @override
  ConsumerState<MechiApp> createState() => _MechiAppState();
}

class _MechiAppState extends ConsumerState<MechiApp> {
  bool get connected => ref.read(apiProvider) != null;
  late final GoRouter router = GoRouter(
    redirect: (_, route) {
      if (!connected) return null;
      final stage = ref.read(sessionProvider).stage;
      final path = route.uri.path;
      if (stage == SessionStage.driverOnboarding) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (stage == SessionStage.mechanicOnboarding) {
        return path == '/mechanic-workspace' ? null : '/mechanic-workspace';
      }
      if (stage != SessionStage.ready) {
        return path == '/account' ? null : '/account';
      }
      if (path == '/mechanic-workspace' ||
          path == '/account' ||
          path == '/onboarding' ||
          [
            '/discover/',
            '/mechanic/',
            '/job/',
            '/receipt/',
            '/review/',
          ].any(path.startsWith)) {
        return '/';
      }
      return null;
    },
    routes: [
      if (connected) _route('/account', (_, _) => const AccountScreen()),
      if (connected)
        _route(
          '/mechanic-workspace',
          (_, _) => const mechanic_workspace.MechanicScreen(),
        ),
      if (connected)
        _route(
          '/onboarding',
          (_, _) => const ConnectedProfile(onboarding: true),
        ),
      _route('/', (_, _) => const HomeScreen()),
      _route('/garage', (_, _) => const GarageScreen()),
      _route(
        '/history',
        (_, _) => connected
            ? _marketplace(
                (owner) => MarketplaceAssignments(key: ValueKey(owner)),
              )
            : const HistoryScreen(),
      ),
      _route(
        '/profile',
        (_, _) => connected ? const ConnectedProfile() : const ProfileScreen(),
      ),
      _route('/request', (_, s) {
        final initial = s.uri.queryParameters['service'] == 'home'
            ? Service.home
            : Service.roadside;
        return connected
            ? _marketplace(
                (owner) => ConnectedRequestScreen(
                  key: ValueKey(owner),
                  initial: initial,
                ),
              )
            : RequestScreen(initial: initial);
      }),
      if (connected)
        _route(
          '/requests/:id',
          (_, s) => _marketplace(
            (owner) => DriverRequestProgress(
              key: ValueKey(owner),
              id: s.pathParameters['id']!,
            ),
          ),
        ),
      if (connected)
        _route(
          '/assignments/:id',
          (_, s) => _marketplace(
            (owner) => MarketplaceAssignments(
              key: ValueKey(owner),
              id: s.pathParameters['id']!,
            ),
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
      if (kDebugMode && !connected)
        _route('/gallery', (_, _) => const GalleryScreen()),
    ],
  );

  Widget _marketplace(Widget Function(String owner) build) => Consumer(
    builder: (context, scoped, _) {
      final owner = scoped.watch(
        sessionProvider.select((value) => value.account?.id),
      );
      return owner == null ? const SizedBox.shrink() : build(owner);
    },
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
  Widget build(BuildContext context) {
    if (connected) ref.listen(sessionProvider, (_, _) => router.refresh());
    return MaterialApp.router(
      title: 'Mechi',
      theme: Mechi.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class MechiConfigurationUnavailable extends StatelessWidget {
  const MechiConfigurationUnavailable({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mechi',
    theme: Mechi.theme,
    debugShowCheckedModeBanner: false,
    home: const Screen(
      title: 'Mechi',
      children: [InformationNotice('Mechi configuration is unavailable.')],
    ),
  );
}
