import 'package:flutter_test/flutter_test.dart';

import 'package:tavsiya/main.dart';

void main() {
  testWidgets('App launches into the language select screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TavsiyaApp());
    await tester.pump();

    expect(find.text('Русский'), findsOneWidget);
    expect(find.text("O'zbekcha"), findsOneWidget);
  });
}
