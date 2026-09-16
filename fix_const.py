with open('b3_app/lib/features/action_plan/screens/action_plan_screen.dart', 'r') as f:
    content = f.read()

old_row = """              Row(
                children: [
                  const Icon(Icons.check_circle, color: B3Theme.b3Green),
                  const SizedBox(width: 8),
                  const Text('Terminé', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold)),
                ]
              ),"""
new_row = """              const Row(
                children: [
                  Icon(Icons.check_circle, color: B3Theme.b3Green),
                  SizedBox(width: 8),
                  Text('Terminé', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold)),
                ]
              ),"""

content = content.replace(old_row, new_row)
with open('b3_app/lib/features/action_plan/screens/action_plan_screen.dart', 'w') as f:
    f.write(content)
