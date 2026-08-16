import 'package:flutter_test/flutter_test.dart';

import 'package:document_organisation/models/document.dart';

void main() {
  group('Document.toMap / fromMap', () {
    test('round-trips every field except actionableDate time-of-day', () {
      final original = Document(
        id: 'doc-1',
        title: 'Council Tax Bill',
        category: 'Bills',
        captureDate: DateTime(2026, 3, 14, 22, 45),
        letterDate: DateTime(2026, 3, 10),
        priority: 'Action Required',
        notes: 'Pay before due date',
        imagePath: '/data/user/0/com.thow76.docubot/app_flutter/docubot_images/doc-1.jpg',
        aiSummary: 'A council tax bill for the current period.',
        aiTags: const ['bill', 'council-tax'],
        actionableDate: DateTime(2026, 4, 1, 9, 30),
        actionableDateContext: 'Payment due date',
      );

      final restored = Document.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.category, original.category);
      expect(restored.captureDate, original.captureDate);
      expect(restored.letterDate, original.letterDate);
      expect(restored.priority, original.priority);
      expect(restored.notes, original.notes);
      expect(restored.imagePath, original.imagePath);
      expect(restored.aiSummary, original.aiSummary);
      expect(restored.aiTags, original.aiTags);
      expect(restored.actionableDateContext, original.actionableDateContext);

      // actionableDate is serialized as a date-only string (see
      // Document.toMap) so the time-of-day component does not survive a
      // round trip — this is existing, intentional behavior, not a bug.
      expect(restored.actionableDate, DateTime(2026, 4, 1));
    });

    test('toMap joins aiTags with commas and fromMap splits them back, dropping empties', () {
      final doc = Document(
        title: 'Test',
        category: 'Other',
        captureDate: DateTime(2026, 1, 1),
        priority: 'Informational',
        imagePath: '/tmp/test.jpg',
        aiTags: const ['a', 'b', 'c'],
      );

      expect(doc.toMap()['aiTags'], 'a,b,c');
      expect(Document.fromMap(doc.toMap()).aiTags, ['a', 'b', 'c']);

      final noTags = doc.copyWith(aiTags: []);
      expect(noTags.toMap()['aiTags'], '');
      expect(Document.fromMap(noTags.toMap()).aiTags, isEmpty);
    });

    test('nullable fields (letterDate, actionableDate) survive a null round trip', () {
      final doc = Document(
        title: 'No dates',
        category: 'Other',
        captureDate: DateTime(2026, 1, 1),
        priority: 'Informational',
        imagePath: '/tmp/test.jpg',
      );

      final restored = Document.fromMap(doc.toMap());
      expect(restored.letterDate, isNull);
      expect(restored.actionableDate, isNull);
    });
  });

  group('Document.copyWith', () {
    test('overrides only the given fields, keeps the rest', () {
      final original = Document(
        title: 'Original',
        category: 'Other',
        captureDate: DateTime(2026, 1, 1),
        priority: 'Informational',
        imagePath: '/tmp/test.jpg',
        actionableDate: DateTime(2026, 2, 1),
      );

      final updated = original.copyWith(title: 'Updated', priority: 'Completed');

      expect(updated.id, original.id);
      expect(updated.title, 'Updated');
      expect(updated.priority, 'Completed');
      expect(updated.category, original.category);
      expect(updated.actionableDate, original.actionableDate);
    });

    test('clearActionableDate removes the date even though a new value was not passed', () {
      final original = Document(
        title: 'Original',
        category: 'Other',
        captureDate: DateTime(2026, 1, 1),
        priority: 'Informational',
        imagePath: '/tmp/test.jpg',
        actionableDate: DateTime(2026, 2, 1),
      );

      final cleared = original.copyWith(clearActionableDate: true);
      expect(cleared.actionableDate, isNull);
    });
  });
}
