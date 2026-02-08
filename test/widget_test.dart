import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Donezy UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Donezy'),
        ),
      ),
    );

    expect(find.text('Donezy'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
