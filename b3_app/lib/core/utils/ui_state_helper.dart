import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/app/theme/theme.dart';

class UiStateHelper {
  static String getLabel(B3State state) {
    switch (state) {
      case B3State.maintained:
        return 'Disponible';
      case B3State.degraded:
        return 'Partiellement disponible';
      case B3State.unknown:
        return 'À vérifier (info manquante)';
      case B3State.notAssessed:
        return 'Non évalué';
      case B3State.failed:
        return 'Indisponible dans ce scénario';
    }
  }

  static Color getColor(B3State state) {
    switch (state) {
      case B3State.maintained:
        return B3Theme.b3Green;
      case B3State.degraded:
        return B3Theme.b3Orange;
      case B3State.unknown:
        return B3Theme.b3Blue;
      case B3State.notAssessed:
        return Colors.grey.shade600;
      case B3State.failed:
        return B3Theme.b3Red;
    }
  }

  static IconData getIcon(B3State state) {
    switch (state) {
      case B3State.maintained:
        return Icons.check_circle;
      case B3State.degraded:
        return Icons.warning_rounded;
      case B3State.unknown:
        return Icons.help_outline;
      case B3State.notAssessed:
        return Icons.radio_button_unchecked;
      case B3State.failed:
        return Icons.cancel;
    }
  }

  static Widget buildStatusChip(B3State state) {
    return Chip(
      avatar: Icon(getIcon(state), size: 16, color: Colors.white),
      label: Text(
        getLabel(state),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: getColor(state),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
