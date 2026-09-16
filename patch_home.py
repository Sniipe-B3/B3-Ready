import re

with open('b3_app/lib/features/home/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Add import
content = "import '../../../data/app_knowledge_dataset.dart';\n" + content

# Fix loadString
old_load = """final knowledgeJson = await DefaultAssetBundle.of(context).loadString('assets/knowledge_base.json');
                            final session = ResilienceSession(
                              knowledgeJson: knowledgeJson,"""
new_load = """final session = ResilienceSession(
                              knowledgeJson: appKnowledgeBase,"""
content = content.replace(old_load, new_load)

with open('b3_app/lib/features/home/screens/home_screen.dart', 'w') as f:
    f.write(content)
