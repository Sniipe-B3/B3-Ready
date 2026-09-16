with open('b3_app/test/ui_flow_test.dart', 'r') as f:
    content = f.read()

content = content.replace("void main() {", "void main() {\n  TestWidgetsFlutterBinding.ensureInitialized();")

with open('b3_app/test/ui_flow_test.dart', 'w') as f:
    f.write(content)
