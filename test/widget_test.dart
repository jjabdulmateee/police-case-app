import 'package:flutter_test/flutter_test.dart';
import 'package:police_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PoliceApp());
    expect(find.text('Case Documentation'), findsOneWidget);
  });
}
