# Phase 04.16.2 — Scenario Fallback & Save State Fix

## Ce qui a été accompli
Cette phase est la finalisation stricte de la résilience locale. Elle corrige les états incohérents lors de la perte ou suppression d'un scénario du knowledge base, le nettoyage propre du flag isSaving, et le chaînage d'une sauvegarde corrective, sans aucune fausse donnée.

1. **Distinction requestedScenarioId / activeScenarioId :**
   La classe `ResilienceSession` reçoit dorénavant un `requestedScenarioId`, mais garde en interne un `_activeScenarioId`. C'est cet ID actif qui est enregistré à chaque autosave, empêchant qu'un ancien ID invalide continue d'empoisonner le JSON du snapshot.

2. **Comportement fallback vers panne_elec :**
   Lors du chargement, si `requestedScenarioId` échoue (parce qu'il n'existe plus), la session tente un fallback vers `panne_elec` (qui devient le nouvel `_activeScenarioId`) et lève le flag `scenarioError` ("Votre ancien scénario n'est plus disponible...").

3. **ID sauvegardé après fallback :**
   La vérification "CORRECTIVE FALLBACK SAVE" (TEST) prouve que dès qu'un fallback vers `panne_elec` est opéré lors d'une restauration de session, un `_autosave()` correctif est déclenché. Ainsi, au prochain lancement, le JSON contient `panne_elec` et l'avertissement d'erreur disparaît (plus de double erreur).

4. **Test restart après fallback :**
   Inclus dans le test "CORRECTIVE FALLBACK SAVE", on restaure le snapshot nouvellement sauvé et on confirme que `scenarioError` est désormais `null`.

5. **Comportement si panne_elec absent aussi :**
   Si même le fallback de sécurité échoue (le scénario `panne_elec` n'existe pas non plus dans la KB), `scenarioUnavailable = true` est activé.

6. **Preuve qu'aucun Scenario artificiel vide n'est simulé :**
   Lorsque `scenarioUnavailable` est vrai, `_simulationResult`, `_recommendations`, et `_actionPlan` restent explicitement `null`. L'appel au moteur `B3Engine().runSimulation()` n'est *pas* fait. L'interface (UI) a été blindée pour cacher le plan d'action et les points de vulnérabilité, affichant seulement une bannière critique "Aucun scénario compatible n'est actuellement disponible."

7. **Logique finale isSaving :**
   L'état `isSaving` repose désormais sur un vrai compteur de file d'attente : `_pendingSaveCount`. L'incrément se fait *avant* de chaîner la tâche à la `_saveQueue` (donc `isSaving` inclut à la fois les saves en cours et les saves en attente). Il est décrémenté dans un bloc `finally`.

8. **Test isSaving :**
   Le test "isSaving logic" a vérifié cet état : on attend la sauvegarde initiale (`isSaving` == false), on lance une complétion (`isSaving` devient `true`), puis on attend la fin (`isSaving` == `false` de nouveau).

9. **Récupération après saveError :**
   Le test "SAVE ERROR RECOVERY" a été modifié pour utiliser un mock toggleable `RecoverableRepo`. Une première écriture échoue et positionne `saveError`. L'écriture suivante, réussie, écrase `saveError` avec `null`, confirmant que l'UI se rétablit.

10. **Résultat dart analyze :**
    `cd packages/b3_engine && dart analyze` ne retourne aucune erreur ni warning. (No issues found).

11. **Nombre tests engine :**
    La suite `b3_engine` complète tourne toujours à 112 tests, 100% au vert.

12. **Résultat flutter analyze :**
    `cd b3_app && flutter analyze` ne retourne aucune erreur ni warning.

13. **Nombre exact tests Flutter :**
    Les tests Flutter (UI, Intégration, Données) exécutent à présent 99 tests (qui intègrent le fallback, l'erreur, le recovery, etc.). 100% au vert.

14. **Résultat build Web :**
    Le `flutter build web --release` s'est exécuté avec succès (51.9s, Wasm dry run succeeded). L'application compile parfaitement.

15. **Git status :**
    L'espace de travail est nettoyé de tous les scripts Python et l'arbre est prêt à être committé via `fix(flutter): finalize persistence fallback handling`.

16. **Limitations restantes :**
    Toutes les contraintes MVP de persistance locale sont résolues de bout en bout et solidifiées. Aucune limitation critique à ce stade.
