with open('b3_app/test/persistence_flow_test.dart', 'r') as f:
    content = f.read()

# Fix resume tap
old_resume = "await tester.tap(find.text('Reprendre mon foyer'));"
new_resume = "final btn = find.text('Reprendre mon foyer');\n    await tester.ensureVisible(btn);\n    await tester.pumpAndSettle();\n    await tester.tap(btn);"
content = content.replace(old_resume, new_resume)

# Fix reset tap
old_reset = "await tester.tap(find.text('Réinitialiser mon foyer'));"
new_reset = "final btnReset = find.text('Réinitialiser mon foyer');\n    await tester.ensureVisible(btnReset);\n    await tester.pumpAndSettle();\n    await tester.tap(btnReset);"
content = content.replace(old_reset, new_reset)

with open('b3_app/test/persistence_flow_test.dart', 'w') as f:
    f.write(content)
