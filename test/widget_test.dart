import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flickr_project/main.dart';
import 'package:flickr_project/providers/auth_provider.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    await tester.pumpWidget(MyApp(authProvider: authProvider));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
