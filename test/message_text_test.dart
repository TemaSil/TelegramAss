import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_liquid/data/models.dart';
import 'package:telegram_liquid/ui/chat/widgets/message_text.dart';

/// Entity offsets come from TDLib and overlap in practice, so the span walk is
/// the part worth pinning down: every character must land in exactly one span.
void main() {
  Future<InlineSpan> renderSpans(
    WidgetTester tester,
    String text,
    List<TgTextEntity> entities,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MessageText(
          text: text,
          entities: entities,
          style: const TextStyle(fontSize: 16),
          linkColor: CupertinoColors.activeBlue,
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text)).textSpan!;
  }

  testWidgets('plain text becomes a single span', (tester) async {
    final span = await renderSpans(tester, 'hello there', const []);
    expect(span.toPlainText(), 'hello there');
  });

  testWidgets('formatting covers exactly its range', (tester) async {
    // "make it bold now" — bold over "bold".
    final span = await renderSpans(tester, 'make it bold now', const [
      TgTextEntity(kind: TgEntityKind.bold, offset: 8, length: 4),
    ]);

    expect(span.toPlainText(), 'make it bold now');

    final children = (span as TextSpan).children!;
    final bold = children.firstWhere(
      (child) => (child as TextSpan).text == 'bold',
    );
    expect((bold as TextSpan).style?.fontWeight, FontWeight.w700);
  });

  testWidgets('entities out of order still keep the text intact', (
    tester,
  ) async {
    final span = await renderSpans(tester, 'one two three', const [
      TgTextEntity(kind: TgEntityKind.italic, offset: 8, length: 5),
      TgTextEntity(kind: TgEntityKind.bold, offset: 0, length: 3),
    ]);
    expect(span.toPlainText(), 'one two three');
  });

  testWidgets('overlapping entities do not duplicate characters', (
    tester,
  ) async {
    final span = await renderSpans(tester, 'abcdef', const [
      TgTextEntity(kind: TgEntityKind.bold, offset: 0, length: 4),
      TgTextEntity(kind: TgEntityKind.italic, offset: 2, length: 4),
    ]);
    expect(span.toPlainText(), 'abcdef');
  });

  testWidgets('a link with an explicit url keeps its visible text', (
    tester,
  ) async {
    final span = await renderSpans(tester, 'see the docs', const [
      TgTextEntity(
        kind: TgEntityKind.link,
        offset: 8,
        length: 4,
        url: 'https://core.telegram.org',
      ),
    ]);
    expect(span.toPlainText(), 'see the docs');
  });

  testWidgets('a spoiler hides its text until tapped', (tester) async {
    final span = await renderSpans(tester, 'the answer is 42', const [
      TgTextEntity(kind: TgEntityKind.spoiler, offset: 14, length: 2),
    ]);

    final hidden = ((span as TextSpan).children!).firstWhere(
      (child) => (child as TextSpan).text == '42',
    );
    expect((hidden as TextSpan).style?.color?.a, 0);
  });
}
