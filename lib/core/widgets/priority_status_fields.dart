import 'package:flutter/material.dart';

import '../domain/priority.dart';
import '../domain/task_status.dart';

/// Priority picker for project and task forms. Always has a value, so an
/// empty choice can't be saved (v1 stored the string "null").
class PriorityField extends StatelessWidget {
  const PriorityField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Priority value;
  final ValueChanged<Priority> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Priority>(
      initialValue: value,
      // Lets long labels shrink instead of overflowing.
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Priority'),
      items: [
        for (final priority in Priority.values)
          DropdownMenuItem(value: priority, child: Text(priority.label)),
      ],
      onChanged: (value) => onChanged(value!),
    );
  }
}

/// Status picker for project and task forms.
class StatusField extends StatelessWidget {
  const StatusField({super.key, required this.value, required this.onChanged});

  final TaskStatus value;
  final ValueChanged<TaskStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TaskStatus>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Status'),
      items: [
        for (final status in TaskStatus.values)
          DropdownMenuItem(value: status, child: Text(status.label)),
      ],
      onChanged: (value) => onChanged(value!),
    );
  }
}
