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
import '../data/task_repository.dart';
import '../domain/task.dart';

/// Opens the form to edit [task], or to add a task to the project with
/// [projectId] (a personal task if that's null too). Resolves to true if it
/// was saved.
Future<bool> showTaskForm(
  BuildContext context, {
  Task? task,
  String? projectId,
}) async =>
    await showAdaptiveSheet<bool>(
      context,
      builder: (context) => TaskForm(task: task, projectId: projectId),
    ) ??
    false;

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm({super.key, this.task, this.projectId});

  /// Null to create a new task.
  final Task? task;

  /// Where a new task goes: a project, or null for a personal task. Ignored
  /// when editing.
  final String? projectId;

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  // Created once with the form, not in build(). v1 set the text in build(),
  // which wiped what you'd typed whenever a dropdown changed.
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  late TaskStatus _status = widget.task?.status ?? TaskStatus.notStarted;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.task == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(taskRepositoryProvider);
    try {
      if (widget.task case final task?) {
        await repository.updateDetails(
          task,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          status: _status,
        );
      } else {
        await repository.createTask(
          projectId: widget.projectId,
          ownerId: ref.read(authRepositoryProvider).currentUser!.uid,
          title: _title.text,
          description: _description.text,
          priority: _priority,
        );
      }
      if (mounted) Navigator.pop(context, true);
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
              _isNew ? 'New task' : 'Edit task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _title,
              autofocus: _isNew,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.required(value, field: 'Title') ??
                  Validators.maxLength(value, 200),
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
              validator: (value) => Validators.maxLength(value, 5000),
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
                // A new task always starts "Not started".
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
                  label: _isNew ? 'Add task' : 'Save',
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
