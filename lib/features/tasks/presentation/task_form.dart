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
import '../domain/checklist_item.dart';
import '../domain/task.dart';
import '../domain/task_repeat.dart';
import 'checklist_editor.dart';
import 'due_date_label.dart';
import 'repeat_label.dart';

/// Opens the form to edit [task], or to add a task to the project with
/// [projectId] (a personal task if that's null too). Pass the project's
/// [members] to offer assigning it. Resolves to true if it was saved.
Future<bool> showTaskForm(
  BuildContext context, {
  Task? task,
  String? projectId,
  Map<String, String>? members,
  DateTime? dueDate,
}) async =>
    await showAdaptiveSheet<bool>(
      context,
      builder: (context) => TaskForm(
        task: task,
        projectId: projectId,
        members: members,
        dueDate: dueDate,
      ),
    ) ??
    false;

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm({
    super.key,
    this.task,
    this.projectId,
    this.members,
    this.dueDate,
  });

  /// Null to create a new task.
  final Task? task;

  /// Where a new task goes: a project, or null for a personal task. Ignored
  /// when editing.
  final String? projectId;

  /// Who the task can be assigned to, as user ID → name. Null for personal
  /// tasks, which have no assignee field.
  final Map<String, String>? members;

  /// The due date a new task starts with. Ignored when editing.
  final DateTime? dueDate;

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
  late DateTime? _dueDate = switch (widget.task) {
    final task? => task.dueDate,
    null => widget.dueDate,
  };
  late TaskRepeat? _repeat = widget.task?.repeat;
  late List<ChecklistItem> _checklist = widget.task?.checklist ?? const [];
  // Shows _dueDate; the field is read-only and opens a date picker.
  final _dueText = TextEditingController();
  // Someone who has left the project shows as unassigned.
  late String? _assigneeId = switch (widget.task?.assigneeId) {
    final id? when widget.members?.containsKey(id) ?? false => id,
    _ => null,
  };
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.task == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Formatting needs the locale, which initState can't read.
    _dueText.text = _formatDue(_dueDate);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _dueText.dispose();
    super.dispose();
  }

  String _formatDue(DateTime? due) => due == null
      ? ''
      : formatDueDate(MaterialLocalizations.of(context), due, DateTime.now());

  void _setDue(DateTime? due) => setState(() {
    _dueDate = due;
    _dueText.text = _formatDue(due);
  });

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'Due date',
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _setDue(picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final localizations = MaterialLocalizations.of(context);
    // A schedule is counted from the due date, so it goes with it.
    final repeat = _dueDate == null ? null : _repeat;
    try {
      if (widget.task case final task?) {
        final next = await repository.updateDetails(
          task,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          status: _status,
          dueDate: _dueDate,
          checklist: _checklist,
          assigneeId: widget.members == null ? null : () => _assigneeId,
          repeat: () => repeat,
        );
        if (next != null) showNextTaskAdded(messenger, localizations, next);
      } else {
        await repository.createTask(
          projectId: widget.projectId,
          ownerId: ref.read(authRepositoryProvider).currentUser!.uid,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          assigneeId: _assigneeId,
          dueDate: _dueDate,
          repeat: repeat,
          checklist: _checklist,
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _dueText,
              readOnly: true,
              onTap: _pickDue,
              decoration: InputDecoration(
                labelText: 'Due date (optional)',
                suffixIcon: _dueDate == null
                    ? IconButton(
                        tooltip: 'Pick a due date',
                        icon: const Icon(Icons.event_outlined),
                        onPressed: _pickDue,
                      )
                    : IconButton(
                        tooltip: 'Clear the due date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => _setDue(null),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TaskRepeat?>(
              // Rebuilt when the due date comes or goes, to enable it.
              key: ValueKey(_dueDate == null),
              initialValue: _dueDate == null ? null : _repeat,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Repeat',
                helperText: _dueDate == null
                    ? 'Pick a due date to repeat the task.'
                    : _repeat == null
                    ? null
                    : 'Completing it adds the next one.',
              ),
              items: [
                const DropdownMenuItem(child: Text("Doesn't repeat")),
                for (final repeat in TaskRepeat.values)
                  DropdownMenuItem(value: repeat, child: Text(repeat.label)),
              ],
              onChanged: _dueDate == null
                  ? null
                  : (value) => setState(() => _repeat = value),
            ),
            if (widget.members case final members?) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _assigneeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assignee'),
                items: [
                  const DropdownMenuItem(child: Text('Unassigned')),
                  for (final MapEntry(key: uid, value: name) in members.entries)
                    DropdownMenuItem(
                      value: uid,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _assigneeId = value),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ChecklistEditor(
              initial: _checklist,
              onChanged: (items) => _checklist = items,
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
