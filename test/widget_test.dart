import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flickr_project/main.dart';
import 'package:flickr_project/providers/auth_provider.dart';
import 'package:flickr_project/providers/theme_provider.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(MyApp(authProvider: authProvider, themeProvider: themeProvider));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
