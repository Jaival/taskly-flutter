import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "New to Taskly? Create an account" and its opposite.
///
/// Replaces the current page instead of pushing, so Back still leads to
/// wherever the user came from, and carries `?from=` over, so they still end
/// up where they were going after signing in.
class SwitchAuthPageLink extends StatelessWidget {
  const SwitchAuthPageLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.path,
  });

  final String prompt;
  final String action;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt),
        TextButton(
          onPressed: () {
            final from = GoRouterState.of(context).uri.queryParameters['from'];
            context.replace(
              Uri(
                path: path,
                queryParameters: from == null ? null : {'from': from},
              ).toString(),
            );
          },
          child: Text(action),
        ),
      ],
    );
  }
}
