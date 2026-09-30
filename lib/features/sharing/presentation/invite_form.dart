import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/project_role.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../../auth/data/auth_repository.dart';
import '../data/invite_repository.dart';
import '../domain/invite.dart';

/// Opens the form to invite someone to a project by email. [memberEmails]
/// are the people already in it. Resolves to true if an invite was sent.
Future<bool> showInviteForm(
  BuildContext context, {
  required String projectId,
  required String projectName,
  required Set<String> memberEmails,
}) async =>
    await showAdaptiveSheet<bool>(
      context,
      builder: (context) => InviteForm(
        projectId: projectId,
        projectName: projectName,
        memberEmails: memberEmails,
      ),
    ) ??
    false;

/// What someone with [role] can do, in a sentence.
String describeRole(ProjectRole role) => switch (role) {
  ProjectRole.owner => 'Can edit everything, manage members and delete it.',
  ProjectRole.editor => 'Can edit the project and add, edit and delete tasks.',
  ProjectRole.viewer =>
    'Can see everything, and tick off tasks assigned to them.',
};

class InviteForm extends ConsumerStatefulWidget {
  const InviteForm({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.memberEmails,
  });

  final String projectId;
  final String projectName;
  final Set<String> memberEmails;

  @override
  ConsumerState<InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends ConsumerState<InviteForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  ProjectRole _role = ProjectRole.editor;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = Invite.normalizeEmail(value ?? '');
    if (email.isEmpty) return 'Enter their email address.';
    if (Validators.email(email) case final error?) return error;
    if (widget.memberEmails.map(Invite.normalizeEmail).contains(email)) {
      return "They're already in this project.";
    }
    return null;
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final email = Invite.normalizeEmail(_email.text);
    try {
      await ref
          .read(inviteRepositoryProvider)
          .sendInvite(
            projectId: widget.projectId,
            projectName: widget.projectName,
            email: email,
            role: _role,
            invitedBy: ref.read(authRepositoryProvider).currentUser!.uid,
          );
      if (mounted) Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text('Invited $email.')));
    } on FirebaseException {
      if (mounted) {
        setState(
          () => _error = "Couldn't send. Check your connection and try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite to ${widget.projectName}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "They'll find the invite under Shared once they sign in with "
              'this email and verify it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _email,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              validator: _validateEmail,
              onFieldSubmitted: (_) => _send(),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ProjectRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Role',
                helperText: describeRole(_role),
                helperMaxLines: 2,
              ),
              items: [
                for (final role in [ProjectRole.editor, ProjectRole.viewer])
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: (value) => setState(() => _role = value!),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              FormError(error),
            ],
            const SizedBox(height: AppSpacing.lg),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.sm,
              overflowSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ProgressButton(
                  label: 'Send invite',
                  busy: _sending,
                  onPressed: _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
