enum UpdateNature {
  observation,
  intervention,
  completion,
}

abstract class HouseholdUpdate {
  final UpdateNature nature;
  const HouseholdUpdate(this.nature);
}

class ResourceUpdate extends HouseholdUpdate {
  final String resourceId;
  final bool? isOwned;
  final Duration? duration;
  final bool isUnknown;

  const ResourceUpdate({
    required this.resourceId,
    this.isOwned,
    this.duration,
    this.isUnknown = false,
    required UpdateNature nature,
  }) : super(nature);
}

class AssetOwnershipUpdate extends HouseholdUpdate {
  final String assetId;
  final bool isOwned;

  const AssetOwnershipUpdate({
    required this.assetId,
    required this.isOwned,
    required UpdateNature nature,
  }) : super(nature);
}

class ActionCompletedUpdate extends HouseholdUpdate {
  final String actionId;

  const ActionCompletedUpdate({
    required this.actionId,
  }) : super(UpdateNature.completion);
}
