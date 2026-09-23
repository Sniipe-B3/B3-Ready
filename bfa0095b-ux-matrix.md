# Phase 04.24 - Manual UX Matrix Report

## 1. Home Screen
- **État Testé** : Premier usage & Reprise
- **Problème** : Boutons étalés sur toute la largeur (desktop), wording technique ("Reset"), confusion sur First Use vs Resume.
- **Correction** : 
  - Ajout `ConstrainedBox(maxWidth: 600)`. 
  - Différenciation claire ("Commencer mon diagnostic" vs "Reprendre mon foyer").
  - Warning explicite dans la modale de réinitialisation ("Toutes les données de votre foyer seront effacées de cet appareil. Cette action est irréversible.").

## 2. Diagnostic Screen
- **État Testé** : Navigation du diagnostic
- **Problème** : "Diagnostic en cours" masquait le contexte (Question X). Soumission multiple sans sélection validait sans erreur. Désélection des autres options lors du clic sur "Je ne sais pas" manquante.
- **Correction** : 
  - Ajout de l'indicateur "Question X". 
  - Ajout du helper texte sous la première question (B3 va analyser...). 
  - Ajout d'une Snackbar pour bloquer l'absence de choix en multiselect. 
  - Logique de désélection implémentée sur toggle.

## 3. Global Overview Screen
- **État Testé** : Synthèse complète du foyer
- **Problème** : Jargon technique dans les cartes d'impact de dépendance, layout trop large sur Desktop, pas d'état vide ("Empty state") satisfaisant si le foyer est parfait.
- **Correction** : 
  - Implémentation de `UiStateHelper` pour éliminer le jargon technique.
  - Ajout `ConstrainedBox(maxWidth: 800)`.
  - Empty state ajouté avec un bouclier: "Aucune fragilité critique croisée n'a été détectée."

## 4. Scenario Overview Screen
- **État Testé** : Liste des scénarios et statuts
- **Problème** : Couleurs en dur (Colors.red, Colors.green), pleine largeur disgracieuse, jargon potentiel.
- **Correction** : 
  - `ConstrainedBox(maxWidth: 600)`.
  - Intégration stricte de `B3Theme.b3Red` / `B3Theme.b3Green`.

## 5. Dependency Map Screen
- **État Testé** : Visualisation d'une vulnérabilité
- **Problème** : Les badges de l'arbre utilisaient les variables techniques du code (`MAINTAINED`, `FAILED`).
- **Correction** : 
  - Intégration complète de `UiStateHelper` pour traduire vers "Disponible", "Indisponible", "À vérifier". 
  - La largeur de l'écran n'a pas été restreinte pour préserver la lisibilité de l'arborescence (Scroll horizontal autorisé).

## 6. Action Plan Screen
- **État Testé** : Liste des recommandations
- **Problème** : Mur d'actions potentiellement intimidant (20+ actions). `_getCapabilityName` hardcodé.
- **Correction** : 
  - Limité aux 5 premières actions par défaut.
  - Bouton "Voir toutes les actions (X masquées)" ajouté.
  - `_getCapabilityName` extrait depuis le graph `session.graph`.
  - Empty state (Foyer préparé) ajouté.

## 7. Guided Action & Progression
- **État Testé** : Action détaillée et Validation
- **Problème** : Message générique "Action enregistrée" même pour une simple coche d'observation. L'Action Plan Screen n'était pas rafraîchi sémantiquement.
- **Correction** : 
  - Message affiné : "Action marquée comme terminée." pour les actions d'apprentissage/organisation. 
  - `ProgressionScreen` amélioré avec labels via `UiStateHelper` (Avant/Après : "Non évalué" -> "Disponible").

## 8. Tests E2E
- 100% Passed. Le flow First Use vs Resume est vérifié (et dimensionné correctement `1080x2400` pour éviter le cropping lors du test Flutter).
