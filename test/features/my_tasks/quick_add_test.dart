import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/features/my_tasks/domain/quick_add.dart';
import 'package:taskly/features/tasks/domain/task_label.dart';

void main() {
  // A Friday.
  final today = DateTime(2026, 10, 16);
  QuickAdd parse(String text, {List<TaskLabel> knownLabels = const []}) =>
      parseQuickAdd(text, today: today, knownLabels: knownLabels);

  test('a plain title is just a title', () {
    final parsed = parse('Water the plants');
    expect(parsed.title, 'Water the plants');
    expect(parsed.dueDate, isNull);
    expect(parsed.priority, isNull);
    expect(parsed.labels, isEmpty);
    expect(parsed.parts, isEmpty);
  });

  test('reads a date, a priority and labels out of the title', () {
    final parsed = parse('Renew passport fri !high #errands #Admin');
    expect(parsed.title, 'Renew passport');
    expect(parsed.dueDate, today);
    expect(parsed.priority, Priority.high);
    expect([for (final l in parsed.labels) l.name], ['errands', 'Admin']);
    expect(
      [for (final (_, _, part) in parsed.parts) part],
      [
        QuickAddPart.date,
        QuickAddPart.priority,
        QuickAddPart.label,
        QuickAddPart.label,
      ],
    );
  });

  group('dates', () {
    for (final (text, expected) in [
      ('today', DateTime(2026, 10, 16)),
      ('tomorrow', DateTime(2026, 10, 17)),
      ('tmr', DateTime(2026, 10, 17)),
      ('monday', DateTime(2026, 10, 19)),
      ('thu', DateTime(2026, 10, 22)),
      ('friday', DateTime(2026, 10, 16)),
      ('next friday', DateTime(2026, 10, 23)),
      ('next week', DateTime(2026, 10, 23)),
      ('next month', DateTime(2026, 11, 16)),
      ('in 3 days', DateTime(2026, 10, 19)),
      ('in 2 weeks', DateTime(2026, 10, 30)),
      ('in 1 month', DateTime(2026, 11, 16)),
      ('oct 23', DateTime(2026, 10, 23)),
      ('23rd october', DateTime(2026, 10, 23)),
      ('Dec 1,', DateTime(2026, 12, 1)),
      // Already past this year: next year's.
      ('jan 5', DateTime(2027, 1, 5)),
    ]) {
      test('"$text"', () {
        final parsed = parse('Call the bank $text');
        expect(parsed.dueDate, expected);
        expect(parsed.title, 'Call the bank');
      });
    }

    test('the last one wins', () {
      expect(parse('a today tomorrow').dueDate, DateTime(2026, 10, 17));
    });

    test('words that are also days are left alone', () {
      for (final text in ['Buy sun cream', 'Sat nav', 'Wed plans']) {
        expect(parse(text).dueDate, isNull, reason: text);
      }
    });

    test('a month needs a day next to it', () {
      final parsed = parse('Plan the march');
      expect(parsed.dueDate, isNull);
      expect(parsed.title, 'Plan the march');
    });

    test('not a real day is not a date', () {
      final parsed = parse('Party feb 30');
      expect(parsed.dueDate, isNull);
      expect(parsed.title, 'Party feb 30');
    });

    test('"in" without a count is just a word', () {
      expect(parse('Check in with Bob').title, 'Check in with Bob');
    });

    test('a month later on the 31st is the end of a shorter month', () {
      final parsed = parseQuickAdd(
        'x next month',
        today: DateTime(2026, 1, 31),
      );
      expect(parsed.dueDate, DateTime(2026, 2, 28));
    });
  });

  group('priority', () {
    for (final (text, expected) in [
      ('!urgent', Priority.immediate),
      ('!1', Priority.immediate),
      ('p1', Priority.immediate),
      ('!HIGH', Priority.high),
      ('!medium', Priority.medium),
      ('!low', Priority.low),
      ('p4', Priority.low),
    ]) {
      test('"$text"', () => expect(parse('x $text').priority, expected));
    }

    test('"!" alone is part of the title', () {
      expect(parse('Ship it!').title, 'Ship it!');
    });
  });

  group('labels', () {
    test('a known label is used, whatever its case', () {
      const design = TaskLabel('Design', color: LabelColor.blue);
      final parsed = parse('Logo #design', knownLabels: [design]);
      expect(parsed.labels, [design]);
    });

    test('a new label gets a colour none of the others have', () {
      const design = TaskLabel('Design', color: LabelColor.red);
      final parsed = parse('Logo #ux #copy', knownLabels: [design]);
      final colors = {design.color, for (final l in parsed.labels) l.color};
      expect(colors, hasLength(3));
    });

    test('the same label twice is one label', () {
      expect(parse('x #ux #UX').labels, hasLength(1));
    });

    test('a "#" inside a word is not a label', () {
      expect(parse('Fix bug#12').title, 'Fix bug#12');
    });
  });

  test('marks where each detail is, to highlight it', () {
    const text = 'Logo tomorrow #design';
    final parsed = parse(text);
    expect(
      [for (final (s, e, _) in parsed.parts) text.substring(s, e)],
      ['tomorrow', '#design'],
    );
  });

  test('a line of only details has no title', () {
    expect(parse('today !high').title, isEmpty);
  });
}
