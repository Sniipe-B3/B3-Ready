import 'package:b3_app/features/action_plan/models/action_plan.dart';

class GuidedActionDetails {
  final ActionPlanItem item;
  final String title;
  final String why;
  final String observed;
  final String todo;
  final String ctaLabel;

  GuidedActionDetails({
    required this.item,
    required this.title,
    required this.why,
    required this.observed,
    required this.todo,
    required this.ctaLabel,
  });
}
