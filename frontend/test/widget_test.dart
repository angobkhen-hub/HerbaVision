// This is a basic Flutter widget test for HerbaVision.
//
// It verifies that the app launches and shows the Splash screen
// (which then leads to Login/Dashboard depending on auth state).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:herbavision/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HerbaVisionApp());

    // Verify the HerbaVision title appears on the splash screen.
    expect(find.text('HerbaVision'), findsOneWidget);

    // Verify a loading indicator is shown while checking auth state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}