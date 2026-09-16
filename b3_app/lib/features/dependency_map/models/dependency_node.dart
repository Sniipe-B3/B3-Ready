import 'package:b3_engine/b3_engine.dart';

enum MapNodeType {
  capability,
  asset,
  system,
  resource
}

class DependencyNode {
  final String id;
  final String label;
  final MapNodeType type;
  final B3State state;
  final List<DependencyNode> children;

  DependencyNode({
    required this.id,
    required this.label,
    required this.type,
    required this.state,
    this.children = const [],
  });
}
