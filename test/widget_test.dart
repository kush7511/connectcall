import 'package:connectcall/widgets/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CommonButton renders label and handles taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonButton(
            label: 'Call',
            icon: Icons.call,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Call'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);

    await tester.tap(find.text('Call'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
