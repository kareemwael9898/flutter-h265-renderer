// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:h265_renderer/main.dart';

void main() {
  testWidgets('H.265 Renderer UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const H265RendererApp());

    // Verify that the title is displayed.
    expect(find.text('H.265 Renderer'), findsOneWidget); // Title widget

    // Verify that default path statuses are shown.
    expect(find.text('Not selected'), findsNWidgets(2));
  });
}
