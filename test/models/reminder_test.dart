import 'package:flutter_test/flutter_test.dart';

import 'package:document_organisation/models/reminder.dart';

void main() {
  group('Reminder.toMap / fromMap', () {
    test('round-trips every field, including isCompleted as an int', () {
      final original = Reminder(
        id: 'rem-1',
        documentId: 'doc-1',
        actionableDate: DateTime(2026, 4, 1, 9, 30),
        contextReason: 'Payment due date',
        notifyDaysBefore: 3,
        isCompleted: false,
        createdAt: DateTime(2026, 3, 14, 22, 45),
      );

      final map = original.toMap();
      expect(map['isCompleted'], 0);

      final restored = Reminder.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.documentId, original.documentId);
      expect(restored.actionableDate, original.actionableDate);
      expect(restored.contextReason, original.contextReason);
      expect(restored.notifyDaysBefore, original.notifyDaysBefore);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.createdAt, original.createdAt);
    });

    test('isCompleted true serializes to 1 and survives the round trip', () {
      final reminder = Reminder(
        documentId: 'doc-1',
        actionableDate: DateTime(2026, 4, 1),
        contextReason: 'Payment due date',
        isCompleted: true,
      );

      expect(reminder.toMap()['isCompleted'], 1);
      expect(Reminder.fromMap(reminder.toMap()).isCompleted, isTrue);
    });
  });

  group('Reminder.copyWith', () {
    test('overrides only the given fields, keeps the rest', () {
      final original = Reminder(
        documentId: 'doc-1',
        actionableDate: DateTime(2026, 4, 1),
        contextReason: 'Payment due date',
        notifyDaysBefore: 1,
      );

      final updated = original.copyWith(isCompleted: true);

      expect(updated.id, original.id);
      expect(updated.documentId, original.documentId);
      expect(updated.actionableDate, original.actionableDate);
      expect(updated.contextReason, original.contextReason);
      expect(updated.notifyDaysBefore, original.notifyDaysBefore);
      expect(updated.isCompleted, isTrue);
    });
  });
}
