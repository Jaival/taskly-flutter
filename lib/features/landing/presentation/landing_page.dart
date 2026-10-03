import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';

/// `/`: what Taskly is, for people who aren't signed in.
///
/// The auth pages are pushed, not gone to, so Back returns here.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text('Taskly', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.push(Routes.login),
            child: const Text('Log in'),
          ),
          if (wide) ...[
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () => context.push(Routes.signUp),
              child: const Text('Sign up'),
            ),
          ],
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: ListView(
        children: const [
          _Section(child: _Hero()),
          _Section(tinted: true, child: _Features()),
          _Section(child: _Showcase()),
          _Section(tinted: true, child: _CallToAction()),
          _Footer(),
        ],
      ),
    );
  }
}

/// A full-width band with its content centred and capped in width.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.tinted = false});

  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tinted
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Text beside a screenshot on wide screens, above it on narrow ones.
class _TextAndShot extends StatelessWidget {
  const _TextAndShot({
    required this.text,
    required this.shot,
    this.shotFirst = false,
  });

  final Widget text;
  final Widget shot;

  /// Put the screenshot on the left when side by side.
  final bool shotFirst;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              text,
              const SizedBox(height: AppSpacing.xl),
              shot,
            ],
          );
        }
        final children = [
          Expanded(flex: 3, child: text),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(flex: 2, child: shot),
        ];
        return Row(children: shotFirst ? children.reversed.toList() : children);
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TextAndShot(
      text: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              'Plan projects. Ship tasks. Together.',
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Taskly keeps your projects, tasks and team in one place, on '
            'your phone and in your browser.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => context.push(Routes.signUp),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Get started'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Free. No credit card.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      shot: const _Screenshot(
        'assets/images/screenshot_home.webp',
        label:
            'The Taskly home screen: counts of projects and tasks, the next '
            'tasks to do and recent projects.',
      ),
    );
  }
}

typedef _Feature = ({IconData icon, String title, String text});

const List<_Feature> _features = [
  (
    icon: Icons.folder_outlined,
    title: 'Projects that stay organised',
    text:
        'Give every project a priority and a status, and see what changed '
        'most recently.',
  ),
  (
    icon: Icons.task_alt,
    title: 'Tasks you can tick off',
    text: 'Personal to-dos and project tasks, each with a priority.',
  ),
  (
    icon: Icons.group_add_outlined,
    title: 'Invite your team',
    text:
        'Invite people by email as editors or viewers. They only see the '
        'projects shared with them.',
  ),
  (
    icon: Icons.assignment_ind_outlined,
    title: 'Clear ownership',
    text: 'Assign tasks to members, so everyone knows what is theirs.',
  ),
  (
    icon: Icons.devices_outlined,
    title: 'On every screen',
    text: 'The same app on your phone, tablet and desktop browser.',
  ),
  (
    icon: Icons.lock_outline,
    title: 'Private by default',
    text:
        'Every read and write is checked on the server, so your work stays '
        'yours.',
  ),
];

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'Everything a small team needs',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = switch (constraints.maxWidth) {
              >= 900 => 3,
              >= 560 => 2,
              _ => 1,
            };
            const gap = AppSpacing.md;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final feature in _features)
                  SizedBox(width: width, child: _FeatureCard(feature)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.feature);

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(feature.icon, color: theme.colorScheme.primary, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(feature.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              feature.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TextAndShot(
      shotFirst: true,
      text: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'A whole project on one page',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "See every task, who it's assigned to and how far along it is. "
            'Owners invite people and choose what they can do; editors plan '
            'the work; viewers tick off what is theirs.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      shot: const _Screenshot(
        'assets/images/screenshot_project.webp',
        label:
            'A project page in Taskly: its tasks with priorities, statuses '
            'and assignees, and its members.',
      ),
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'Ready to get organised?',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.push(Routes.signUp),
          child: const Text('Create your free account'),
        ),
      ],
    );
  }
}

/// A phone screenshot with rounded corners and an outline.
class _Screenshot extends StatelessWidget {
  const _Screenshot(this.asset, {required this.label});

  final String asset;

  /// What the screenshot shows, for screen readers.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const frame = 6.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Follows the screenshot's corners around the outside.
            borderRadius: BorderRadius.circular(AppRadius.lg + frame),
            border: Border.all(color: colors.outlineVariant, width: frame),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.lgAll,
            child: Image.asset(asset, semanticLabel: label),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Taskly · Built with Flutter and Firebase',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
