import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/tasks/data/task_firestore.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/domain/task_activity.dart';
import 'package:taskly/features/tasks/domain/task_label.dart';
import 'package:taskly/features/tasks/domain/task_repeat.dart';

const _design = TaskLabel('Design', color: LabelColor.blue);
const _bug = TaskLabel('Bug', color: LabelColor.red);

void main() {
  group('labels', () {
    test('are the same label whatever the case or spaces', () {
      expect(const TaskLabel(' Design ').key, _design.key);
      expect(const TaskLabel('DESIGN').key, 'design');
    });

    test('an unknown stored colour is grey', () {
      expect(LabelColor.fromName('blue'), LabelColor.blue);
      expect(LabelColor.fromName('chartreuse'), LabelColor.grey);
      expect(LabelColor.fromName(null), LabelColor.grey);
    });

    test('tidied: trimmed, without blanks or repeats, at most ten', () {
      expect(
        tidyLabels(const [
          TaskLabel('  Design '),
          TaskLabel('   '),
          TaskLabel('design', color: LabelColor.red),
          _bug,
        ]),
        const [TaskLabel('Design'), _bug],
      );
      expect(
        tidyLabels([for (var i = 0; i < 12; i++) TaskLabel('L$i')]),
        hasLength(maxTaskLabels),
      );
    });

    test('in use: each once, A to Z, the first one seen winning', () {
      expect(
        labelsInUse(const [
          [_design],
          [TaskLabel('design', color: LabelColor.pink), _bug],
          [],
        ]),
        const [_bug, _design],
      );
    });

    test('replacing renames, recolours, merges or removes', () {
      const urgent = TaskLabel('Urgent', color: LabelColor.orange);
      expect(replaceLabel(const [_design, _bug], _design, urgent), const [
        urgent,
        _bug,
      ]);
      expect(
        replaceLabel(const [_design], _design, _design.copyWith(name: 'UX')),
        const [TaskLabel('UX', color: LabelColor.blue)],
      );
      // Renamed to Bug: one Bug, in the new colour.
      const greenBug = TaskLabel('bug', color: LabelColor.green);
      expect(replaceLabel(const [_design, _bug], _design, greenBug), const [
        greenBug,
      ]);
      expect(replaceLabel(const [_design, _bug], _design, null), const [_bug]);
    });

    test('a new label gets a colour not in use yet', () {
      expect(unusedLabelColor(const []), LabelColor.red);
      expect(unusedLabelColor(const [_bug]), LabelColor.orange);
      final allButGrey = [
        for (final color in LabelColor.values.skip(1))
          TaskLabel('x', color: color),
      ];
      expect(unusedLabelColor(allButGrey), LabelColor.grey);
    });

    test('stored as names and colours; anything odd is skipped', () {
      expect(labelsToFirestore(const [_design]), [
        {'name': 'Design', 'color': 'blue'},
      ]);
      expect(
        labelsFromFirestore([
          {'name': 'Design', 'color': 'blue'},
          {'name': 'Old', 'color': 'mauve'},
          {'name': '  '},
          'Bug',
          7,
        ]),
        const [_design, TaskLabel('Old')],
      );
      expect(labelsFromFirestore(null), isEmpty);
      expect(labelsFromFirestore('Design'), isEmpty);
    });
  });

  group('the repository', () {
    late FakeFirebaseFirestore db;
    late TaskRepository repository;
    var now = DateTime(2026, 10, 5, 9);
    const alice = AppUser(uid: 'alice', email: 'alice@example.com');

    setUp(() {
      db = FakeFirebaseFirestore();
      now = DateTime(2026, 10, 5, 9);
      repository = TaskRepository(
        db,
        clock: () => now,
        currentUser: () => alice,
      );
    });

    Future<String> create(
      String title, {
      String? projectId = 'p1',
      String ownerId = 'alice',
      List<TaskLabel> labels = const [],
      TaskRepeat? repeat,
    }) async {
      final id = await repository.createTask(
        projectId: projectId,
        ownerId: ownerId,
        title: title,
        labels: labels,
        dueDate: repeat == null ? null : DateTime(2026, 10, 5),
        repeat: repeat,
      );
      now = now.add(const Duration(minutes: 1));
      return id;
    }

    Future<List<Task>> projectTasks() =>
        repository.watchProjectTasks('p1').first;

    Future<List<String>> loggedKinds(String taskId) async => [
      for (final entry in (await repository.watchActivity('p1', taskId).first))
        entry.kind.name,
    ];

    test('a new task keeps its labels, tidied', () async {
      await create('Logo', labels: const [_design, TaskLabel(' design ')]);
      expect((await projectTasks()).single.labels, const [_design]);
    });

    test('editing the labels changes them, and logs it', () async {
      final id = await create('Logo', labels: const [_design]);
      final task = (await projectTasks()).single;

      await repository.updateDetails(
        task,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: task.status,
        dueDate: task.dueDate,
        labels: const [_design, _bug],
      );

      expect((await projectTasks()).single.labels, const [_design, _bug]);
      expect(await loggedKinds(id), contains(ActivityKind.labels.name));
      final entry = (await repository.watchActivity('p1', id).first).last;
      expect(entry.value, 'Design\nBug');
    });

    test('labels left out of an edit stay as they were', () async {
      await create('Logo', labels: const [_design]);
      final task = (await projectTasks()).single;

      await repository.updateDetails(
        task,
        title: 'New logo',
        description: '',
        priority: Priority.high,
        status: TaskStatus.inProgress,
        dueDate: null,
      );

      expect((await projectTasks()).single.labels, const [_design]);
    });

    test('the next task in a series has the same labels', () async {
      await create('Report', labels: const [_bug], repeat: TaskRepeat.weekly);
      await repository.setStatus(
        (await projectTasks()).single,
        TaskStatus.complete,
      );
      final [_, next] = await projectTasks();
      expect(next.labels, const [_bug]);
    });

    test('a label is renamed and recoloured on every task with it', () async {
      await create('Logo', labels: const [_design, _bug]);
      await create('Icons', labels: const [TaskLabel('design')]);
      await create('Copy', labels: const [_bug]);

      final changed = await repository.editLabel(
        projectId: 'p1',
        ownerId: 'alice',
        from: _design,
        to: const TaskLabel('UX', color: LabelColor.teal),
      );

      expect(changed, 2);
      const ux = TaskLabel('UX', color: LabelColor.teal);
      expect(
        [for (final task in await projectTasks()) task.labels],
        const [
          [ux, _bug],
          [ux],
          [_bug],
        ],
      );
    });

    test('renaming onto another label merges them', () async {
      await create('Logo', labels: const [_design, _bug]);
      await create('Copy', labels: const [_bug]);

      await repository.editLabel(
        projectId: 'p1',
        ownerId: 'alice',
        from: _design,
        to: const TaskLabel('Bug', color: LabelColor.green),
      );

      const greenBug = TaskLabel('Bug', color: LabelColor.green);
      expect(
        [for (final task in await projectTasks()) task.labels],
        const [
          [greenBug],
          [greenBug],
        ],
      );
    });

    test('deleting a label takes it off, and leaves the tasks', () async {
      await create('Logo', labels: const [_design, _bug]);

      await repository.editLabel(projectId: 'p1', ownerId: 'alice', from: _bug);

      expect((await projectTasks()).single.labels, const [_design]);
    });

    test("personal labels change only on the user's own tasks", () async {
      await create('Mine', projectId: null, labels: const [_design]);
      await create(
        'Theirs',
        projectId: null,
        ownerId: 'bob',
        labels: const [_design],
      );
      await create('In a project', labels: const [_design]);

      await repository.editLabel(ownerId: 'alice', from: _design);

      expect(
        (await repository.watchPersonalTasks('alice').first).single.labels,
        isEmpty,
      );
      expect(
        (await repository.watchPersonalTasks('bob').first).single.labels,
        const [_design],
      );
      expect((await projectTasks()).single.labels, const [_design]);
    });
  });
}
