import 'package:ClashF/NavigationService.dart';
import 'package:ClashF/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toast disappears within five seconds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    showToast('hello');
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsNothing);
  });
}
