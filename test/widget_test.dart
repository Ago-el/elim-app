import 'package:flutter_test/flutter_test.dart';

import 'package:elim/main.dart';

void main() {

  testWidgets('ELIM smoke test', (tester) async {

    await tester.pumpWidget(const ElimApp());

    expect(find.byType(ElimApp), findsOneWidget);

  });

}
