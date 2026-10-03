import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/my_tasks/domain/my_task.dart';
import 'package:taskly/features/my_tasks/domain/task_filter.dart';
import 'package:taskly/features/projects/domain/project.dart';
import 'package:taskly/features/tasks/domain/due_date.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/domain/task_label.dart';

void main() {
  final today = DateTime(2026, 10, 1);
  const launch = Project(
    id: 'p1',
    ownerId: 'bob',
    name: 'Launch',
    memberIds: ['bob', 'alice'],
    roles: {'bob': ProjectRole.owner, 'alice': ProjectRole.editor},
  );

  MyTask item(
    String title, {
    String description = '',
    Priority priority = Priority.medium,
    TaskStatus status = TaskStatus.notStarted,
    DateTime? due,
    DateTime? created,
    bool inProject = false,
    List<TaskLabel> labels = const [],
  }) => MyTask(
    Task(
      id: title,
      ownerId: 'alice',
      title: title,
      description: description,
      priority: priority,
      status: status,
      dueDate: due,
      createdAt: created,
      projectId: inProject ? 'p1' : null,
      labels: labels,
    ),
    project: inProject ? launch : null,
  );

  List<String> titles(TaskFilter filter, List<MyTask> items) => [
    for (final item in filter.apply(items, today)) item.task.title,
  ];

  test('search matches the title or description, ignoring case', () {
    final items = [
      item('Buy milk'),
      item('Call Ada', description: 'About the MILK order'),
      item('Walk the dog'),
    ];
    expect(titles(const TaskFilter(query: ' milk '), items), [
      'Buy milk',
      'Call Ada',
    ]);
  });

  test('each filter keeps any of its choices, and all must match', () {
    final items = [
      item('a', priority: Priority.high),
      item('b', priority: Priority.low),
      item('c', priority: Priority.high, status: TaskStatus.complete),
      item('d', priority: Priority.immediate, inProject: true),
    ];
    expect(
      titles(
        const TaskFilter(priorities: {Priority.high, Priority.immediate}),
        items,
      ),
      ['a', 'c', 'd'],
    );
    expect(
      titles(
        const TaskFilter(
          priorities: {Priority.high},
          statuses: {TaskStatus.notStarted},
        ),
        items,
      ),
      ['a'],
    );
  });

  test('filters by project, with null for personal tasks', () {
    final items = [item('mine'), item('launch', inProject: true)];
    expect(titles(const TaskFilter(projectIds: {null}), items), ['mine']);
    expect(titles(const TaskFilter(projectIds: {'p1'}), items), ['launch']);
    expect(titles(const TaskFilter(projectIds: {null, 'p1'}), items), [
      'mine',
      'launch',
    ]);
  });

  test('search matches labels too', () {
    final items = [
      item('Logo', labels: const [TaskLabel('Design')]),
      item('Designer brief'),
      item('Copy'),
    ];
    expect(titles(const TaskFilter(query: 'desig'), items), [
      'Logo',
      'Designer brief',
    ]);
  });

  test('filters by label, by name across projects, ignoring case', () {
    final items = [
      item('mine', labels: const [TaskLabel('Design')]),
      item(
        'launch',
        inProject: true,
        labels: const [TaskLabel('design', color: LabelColor.red)],
      ),
      item('bug', labels: const [TaskLabel('Bug')]),
      item('none'),
    ];
    const filter = TaskFilter(labels: {'design'});
    expect(filter.isFiltering, isTrue);
    expect(titles(filter, items), ['mine', 'launch']);
    expect(titles(const TaskFilter(labels: {'design', 'bug'}), items), [
      'mine',
      'launch',
      'bug',
    ]);
  });

  test('filters by when it is due', () {
    final items = [
      item('late', due: DateTime(2026, 9, 20)),
      item(
        'late but done',
        due: DateTime(2026, 9, 20),
        status: TaskStatus.complete,
      ),
      item('today', due: today),
      item('someday'),
    ];
    expect(titles(const TaskFilter(due: {DueGroup.overdue}), items), ['late']);
    expect(
      titles(const TaskFilter(due: {DueGroup.today, DueGroup.noDate}), items),
      ['today', 'someday'],
    );
  });

  test('sorts by priority, then by due date', () {
    final items = [
      item('low', priority: Priority.low),
      item('high undated', priority: Priority.high),
      item('high soon', priority: Priority.high, due: DateTime(2026, 10, 2)),
      item('immediate', priority: Priority.immediate),
    ];
    expect(titles(const TaskFilter(sort: TaskSort.priority), items), [
      'immediate',
      'high soon',
      'high undated',
      'low',
    ]);
  });

  test('sorts newest first, with unsaved tasks at the top', () {
    final items = [
      item('old', created: DateTime(2026, 1, 1)),
      item('unsaved'),
      item('new', created: DateTime(2026, 9, 1)),
    ];
    expect(titles(const TaskFilter(sort: TaskSort.newest), items), [
      'unsaved',
      'new',
      'old',
    ]);
  });

  test('sorts by title, ignoring case', () {
    final items = [item('banana'), item('Apple'), item('cherry')];
    expect(titles(const TaskFilter(sort: TaskSort.title), items), [
      'Apple',
      'banana',
      'cherry',
    ]);
  });

  test('the due date sort keeps list order, for grouping later', () {
    final items = [item('b', due: today), item('a')];
    expect(titles(const TaskFilter(), items), ['b', 'a']);
  });

  test('clearing keeps the sort, and the sort is not a filter', () {
    const filter = TaskFilter(
      query: 'x',
      priorities: {Priority.low},
      sort: TaskSort.title,
    );
    expect(filter.isFiltering, isTrue);
    expect(filter.cleared(), const TaskFilter(sort: TaskSort.title));
    expect(filter.cleared().isFiltering, isFalse);
    expect(const TaskFilter(query: '   ').isFiltering, isFalse);
  });
}
