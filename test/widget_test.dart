import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frozencatch/main.dart';

void main() {
  testWidgets('App boots and shows the loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FrozenCatchApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
