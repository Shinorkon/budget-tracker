import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app_flutter/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetApp());
    // Basic smoke test - the app should render
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
