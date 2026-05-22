import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shwapy_mobile/main.dart';

void main() {
  testWidgets('renders the Shwapy app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ShwapyApp(cameras: []));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Shwapy');
  });
}
