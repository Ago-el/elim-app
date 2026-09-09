import 'package:flutter_test/flutter_test.dart';
import 'package:elim/main.dart';
void main(){testWidgets('ELIM renders', (tester) async {await tester.pumpWidget(const ElimApp());expect(find.text('ELIM'),findsWidgets);});}
