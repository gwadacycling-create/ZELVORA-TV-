import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/core/widgets/h_scroller.dart';

void main() {
  testWidgets('rangée : flèches pour voir la suite quand elle déborde', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: HScroller(
            height: 80,
            itemCount: 20,
            itemBuilder: (_, i) => SizedBox(width: 150, child: Text('Tuile $i')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scroll-left')), findsNothing);
    expect(find.byKey(const Key('scroll-right')), findsOneWidget);
    expect(find.text('Tuile 6'), findsNothing);

    await tester.tap(find.byKey(const Key('scroll-right')));
    await tester.pumpAndSettle();
    expect(find.text('Tuile 6'), findsOneWidget);
    expect(find.byKey(const Key('scroll-left')), findsOneWidget);
  });
}
