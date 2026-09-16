import re

with open('b3_app/lib/features/home/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Remove _resume method
content = re.sub(r"  void _resume\(\) \{\n.*?  \}", "", content, flags=re.DOTALL)

with open('b3_app/lib/features/home/screens/home_screen.dart', 'w') as f:
    f.write(content)

with open('b3_app/lib/features/action_plan/screens/action_plan_screen.dart', 'r') as f:
    content = f.read()

# Add consts in action_plan_screen.dart
# The lines are:
# BoxShadow(
#   color: Colors.black.withOpacity(0.05),
#   offset: Offset(0, 2),
#   blurRadius: 4,
# ),
# Actually, withOpacity doesn't allow const. Oh, it might be something else. Let's find it.
# Let's just fix it by running dart format or manually. Wait, I will use sed for basic ones.
