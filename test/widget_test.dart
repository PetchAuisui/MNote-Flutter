import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';

void main() {
  testWidgets('shows the Mnote workspace placeholder', (tester) async {
    await tester.pumpWidget(const MnoteApp());

    expect(find.text('Mnote'), findsOneWidget);
    expect(find.text('Read Markdown. Write freely.'), findsOneWidget);
  });
}
