abstract class HouseholdUpdate {
  const HouseholdUpdate();
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
  });
}

class AssetOwnershipUpdate extends HouseholdUpdate {
  final String assetId;
  final bool isOwned;

  const AssetOwnershipUpdate({
    required this.assetId,
    required this.isOwned,
  });
}

class ActionCompletedUpdate extends HouseholdUpdate {
  final String actionId;

  const ActionCompletedUpdate({
    required this.actionId,
  });
}
