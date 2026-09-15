import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/app/app.dart';

void main() {
  testWidgets('Parcours complet: Home -> Diagnostic -> Results',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pumpAndSettle();

    expect(find.text('B3 Ready'), findsOneWidget);
    
    final btnStart = find.widgetWithText(FilledButton, 'Commencer mon diagnostic');
    await tester.ensureVisible(btnStart);
    await tester.pumpAndSettle();
    await tester.tap(btnStart);
    await tester.pumpAndSettle();

    // 1. Question: Chauffage (multiple_choice)
    expect(find.text('Comment chauffez-vous principalement votre logement ?'), findsOneWidget);
    await tester.tap(find.text('Radiateurs électriques'));
    await tester.pumpAndSettle();
    
    // Back and forth test
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Commencer mon diagnostic'), findsOneWidget); 
    await tester.tap(btnStart);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Radiateurs électriques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 2. Question: Cuisine (multiple_choice)
    expect(find.text('De quels équipements disposez-vous pour cuisiner ?'), findsOneWidget);
    await tester.tap(find.text('Plaque électrique / induction')); // Select checkbox
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 3. Question: Éclairage (multiple_choice)
    expect(find.text("De quoi disposez-vous pour l'éclairage en cas de coupure électrique ?"), findsOneWidget);
    await tester.tap(find.text('Rien de spécifique (luminaires branchés sur secteur)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Résultats
    expect(find.text('Bilan de résilience'), findsOneWidget);
    
    final fullTextStr = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    expect(fullTextStr.contains('total point >'), false);
    expect(fullTextStr.contains('\${totalPoints'), false);
    expect(fullTextStr.contains('system_'), false);
    expect(fullTextStr.contains('cuisiner_failed'), false);
    expect(fullTextStr.contains('causeNodeIds'), false);
    expect(fullTextStr.contains('B3State.degraded'), false);

    expect(find.textContaining('points de vigilance'), findsOneWidget);

    expect(find.text('CUISINER'), findsOneWidget);
    expect(find.text('SE CHAUFFER'), findsOneWidget);

    await tester.ensureVisible(find.text('Comprendre').first);
    await tester.tap(find.text('Comprendre').first);
    await tester.pumpAndSettle();

    expect(find.text('Pourquoi ?'), findsOneWidget);
    expect(find.text('Ce que cela signifie'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    expect(find.text('Bilan de résilience'), findsOneWidget);
    
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
