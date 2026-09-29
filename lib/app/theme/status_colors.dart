import 'package:flutter/material.dart';

import '../../core/domain/task_status.dart';

/// Status colours come from the Material colour scheme, so they follow the
/// brand seed and dark mode automatically.
extension StatusColors on ColorScheme {
  Color statusColor(TaskStatus status) => switch (status) {
    TaskStatus.notStarted => outline,
    TaskStatus.inProgress => tertiary,
    TaskStatus.complete => primary,
  };
}
