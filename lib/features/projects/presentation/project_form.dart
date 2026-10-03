import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/priority_status_fields.dart';
import '../../../core/widgets/progress_button.dart';
import '../../auth/data/auth_repository.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';

/// Opens the form to create a project, or to edit [project]. Resolves to the
/// project's ID if it was saved.
Future<String?> showProjectForm(BuildContext context, {Project? project}) =>
    showAdaptiveSheet<String>(
      context,
      builder: (context) => ProjectForm(project: project),
    );

class ProjectForm extends ConsumerStatefulWidget {
  const ProjectForm({super.key, this.project});

  /// Null to create a new project.
  final Project? project;

  @override
  ConsumerState<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late Priority _priority = widget.project?.priority ?? Priority.medium;
  late TaskStatus _status = widget.project?.status ?? TaskStatus.notStarted;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.project == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(projectRepositoryProvider);
    try {
      final String id;
      if (widget.project case final project?) {
        id = project.id;
        await repository.updateDetails(
          id,
          name: _name.text,
          description: _description.text,
          priority: _priority,
          status: _status,
        );
      } else {
        id = await repository.createProject(
          ownerId: ref.read(authRepositoryProvider).currentUser!.uid,
          name: _name.text,
          description: _description.text,
          priority: _priority,
        );
      }
      if (mounted) Navigator.pop(context, id);
    } on FirebaseException {
      if (mounted) {
        setState(
          () => _error = "Couldn't save. Check your connection and try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? 'New project' : 'Edit project',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              autofocus: _isNew,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.required(value, field: 'Name') ??
                  Validators.maxLength(value, 100),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
              validator: (value) => Validators.maxLength(value, 2000),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: PriorityField(
                    value: _priority,
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                ),
                // A new project always starts "Not started".
                if (!_isNew) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatusField(
                      value: _status,
                      onChanged: (value) => setState(() => _status = value),
                    ),
                  ),
                ],
              ],
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              FormError(error),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Wraps the buttons onto two lines if they don't fit side by side
            // (narrow phones, large text settings).
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.sm,
              overflowSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ProgressButton(
                  label: _isNew ? 'Create project' : 'Save',
                  busy: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
