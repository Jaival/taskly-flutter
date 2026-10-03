import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/delete_account.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/landing/presentation/landing_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/projects/presentation/project_detail_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/projects/presentation/shared_page.dart';
import '../features/my_tasks/presentation/tasks_page.dart';
import '../core/widgets/page_title.dart';
import 'app_shell.dart';
import 'not_found_page.dart';

abstract final class Routes {
  static const landing = '/';
  static const login = '/login';
  static const signUp = '/signup';

  static const home = '/home';
  static const projects = '/projects';
  static String project(String id) => '/projects/$id';
  static const tasks = '/tasks';
  static const shared = '/shared';
  static const profile = '/profile';
}

/// Pages that signed-out users may visit. Signed-in users are sent past them.
const _publicPaths = {Routes.landing, Routes.login, Routes.signUp};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _StreamListenable(auth.userChanges());

  final router = GoRouter(
    initialLocation: Routes.landing,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(signedIn: auth.currentUser != null, uri: state.uri),
    errorBuilder: (context, state) =>
        const PageTitle('Page not found', child: NotFoundPage()),
    routes: [
      GoRoute(
        path: Routes.landing,
        builder: (context, state) =>
            const PageTitle(null, child: LandingPage()),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            const PageTitle('Log in', child: LoginPage()),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) =>
            const PageTitle('Sign up', child: SignUpPage()),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const PageTitle(
          'Profile',
          child: ProfilePage(footer: DeleteAccountCard()),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          projectId: state.pathParameters['id'],
          // Nested pages like /projects/:id bring their own app bar with a
          // back button.
          showAppBar: state.uri.pathSegments.length <= 1,
        ),
        branches: [
          _branch(Routes.home, 'Home', const HomePage()),
          _branch(
            Routes.projects,
            'Projects',
            const ProjectsPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    ProjectDetailPage(projectId: state.pathParameters['id']!),
              ),
            ],
          ),
          _branch(Routes.tasks, 'Tasks', const TasksPage()),
          _branch(Routes.shared, 'Shared', const SharedPage()),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

StatefulShellBranch _branch(
  String path,
  String title,
  Widget page, {
  List<RouteBase> routes = const [],
}) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      builder: (context, state) => PageTitle(title, child: page),
      routes: routes,
    ),
  ],
);

/// Sends signed-out users to the login page, remembering where they were
/// going in `?from=`, and sends signed-in users away from the public pages.
@visibleForTesting
String? authRedirect({required bool signedIn, required Uri uri}) {
  final isPublic = _publicPaths.contains(uri.path);

  if (!signedIn && !isPublic) {
    return Uri(
      path: Routes.login,
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (signedIn && isPublic) {
    final from = uri.queryParameters['from'];
    return _isSafeReturnPath(from) ? from : Routes.home;
  }
  return null;
}

/// Only allow relative in-app paths, so `?from=` can't redirect off-site or
/// back into a public page.
bool _isSafeReturnPath(String? path) =>
    path != null &&
    path.startsWith('/') &&
    !path.startsWith('//') &&
    !_publicPaths.contains(Uri.parse(path).path);

/// Notifies go_router to re-run [GoRouter.redirect] whenever auth state
/// changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
