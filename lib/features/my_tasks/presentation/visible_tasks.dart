import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/undo_delete.dart';
import '../../tasks/presentation/task_card.dart';
import '../data/my_tasks_provider.dart';
import '../domain/my_task.dart';

/// The user's tasks, less any just deleted whose "Undo" is still showing.
final visibleTasksProvider = Provider.autoDispose<AsyncValue<List<MyTask>>>((
  ref,
) {
  final hidden = ref.watch(pendingDeletionsProvider);
  return ref
      .watch(myTasksProvider)
      .whenData(
        (items) => [
          for (final item in items)
            if (!hidden.contains(taskDeletionKey(item.task))) item,
        ],
      );
});
