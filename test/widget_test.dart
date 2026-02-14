import 'package:flutter_test/flutter_test.dart';
import 'package:sift_app/main.dart';

void main() {
  testWidgets('SiftApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SiftApp());

    // Verify that our app starts.
    expect(find.byType(SiftApp), findsOneWidget);
  });
}
