import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';
import '../models/household_update.dart';

class ActionUpdateResolver {
  static UpdateNature _determineNature(ActionPlanItem item) {
    if (item.type == RecommendationType.verify) {
      return UpdateNature.observation;
    }
    return UpdateNature.intervention;
  }

  static HouseholdUpdate resolveResourceUpdate(ActionPlanItem item, bool? isOwned, Duration? duration, bool isUnknown) {
    return ResourceUpdate(
      resourceId: item.targetResourceId!,
      isOwned: isOwned,
      duration: duration,
      isUnknown: isUnknown,
      nature: _determineNature(item),
    );
  }

  static HouseholdUpdate resolveAssetUpdate(ActionPlanItem item, bool isOwned) {
    return AssetOwnershipUpdate(
      assetId: item.targetAssetId!,
      isOwned: isOwned,
      nature: _determineNature(item),
    );
  }

  static HouseholdUpdate resolveActionCompleted(ActionPlanItem item) {
    return ActionCompletedUpdate(actionId: item.id);
  }
}
