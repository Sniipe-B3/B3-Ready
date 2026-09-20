# Phase 04.16.1 — Local Persistence Hardening

## Ce qui a été accompli
Cette phase de consolidation (hardening) s'assure que la persistance locale est non seulement fonctionnelle (comme dans le MVP), mais également robuste, déterministe et sûre face aux erreurs. Aucune nouvelle fonctionnalité produit n'a été ajoutée.

1. **Pourquoi save() silencieux était problématique :**
   Avant cette phase, `SharedPrefsHouseholdRepository.save()` masquait toutes les erreurs via un bloc `try/catch` vide. Cela signifiait que si le stockage local était plein ou indisponible, l'application continuait de fonctionner en mémoire sans avertir l'utilisateur, causant une perte silencieuse de données à la fermeture.

2. **Comportement final Repository.save :**
   Le bloc `try/catch` a été supprimé de `SharedPrefsHouseholdRepository.save()`. Les exceptions sont désormais propagées (throw) à l'appelant.

3. **État d'erreur exposé par ResilienceSession :**
   La session intercepte maintenant ces erreurs dans sa fonction `_autosave()` et expose une propriété `saveError` (de type `Object?`). Si cette valeur est non-nulle, l'UI (ou les tests) peut savoir que la dernière sauvegarde a échoué.

4. **Stratégie pendingSave :**
   Le comportement fire-and-forget de `_autosave()` a été remplacé par une file d'attente asynchrone (`_saveQueue`). Chaque écriture attend la fin de la précédente (`_saveQueue = _saveQueue.then(...)`). Une méthode publique `waitForPendingSave()` permet d'attendre la complétion de la file (indispensable pour les tests déterministes).

5. **Test save failure :**
   Le test `TEST 5 — FAIL SAVE` utilise un `FailingHouseholdRepository`. Il vérifie que l'erreur de sauvegarde ne fait pas planter le recalcul métier de `B3Engine`, que l'état en mémoire est bien mis à jour, et que la propriété `saveError` reflète bien l'échec.

6. **Sauvegarde initiale :**
   Lors de la création d'une nouvelle `ResilienceSession` (à la fin du diagnostic), un `_autosave()` initial est déclenché automatiquement si le paramètre booléen `isRestored` est `false`. L'utilisateur peut ainsi fermer immédiatement l'application après le diagnostic et reprendre plus tard sans perdre son état.

7. **Test sauvegarde initiale sans update :**
   Le test `TEST 8 — INITIAL SAVE` vérifie qu'une nouvelle session s'enregistre immédiatement dans le dépôt, sans même avoir besoin d'attendre une première action utilisateur (update).

8. **Traitement scénario invalide :**
   Si un utilisateur reprend une session liée à un scénario qui a été supprimé de la base de connaissances (ex: `ancien_scenario_supprime`), la session intercepte l'erreur, expose un message dans `scenarioError` ("Votre ancien scénario n'est plus disponible..."), et utilise explicitement `panne_elec` comme scénario de secours. Si ce fallback échoue aussi, un scénario inoffensif vide est instancié. Pas de crash ni d'écran blanc.

9. **Test scénario invalide :**
   Le test `TEST 10 — UNKNOWN SCENARIO` restaure une session avec un ID de scénario supprimé et confirme qu'aucune exception n'est jetée, que le fallback a bien lieu et que le calcul de la simulation reste valide.

10. **Comportement corruption :**
    La logique existante du `load()` retourne `null` si le JSON est corrompu ou illisible. Ce comportement a été conservé car jugé acceptable pour le MVP (l'utilisateur recommencera le diagnostic, ce qui est préférable à une application bloquée).

11. **Comportement completion autosave :**
    La mise à jour de complétion d'action (`ActionCompletedUpdate`) déclenche `_autosave()` en utilisant désormais la nouvelle infrastructure en file d'attente (`_saveQueue`). `Future.delayed(Duration.zero)` a été éliminé des tests.

12. **Absence de données dérivées :**
    Il est confirmé (et vérifié dans `HouseholdSnapshot`) que ni `SimulationResult`, `Recommendation`, `ActionPlan`, ou `DependencyMap` ne sont stockés. Seules les données primaires sont sauvées (`HouseholdConfig`, `scenarioId`, `completedActionIds`, et métadonnées).

13. **Résultat restart/recalculate :**
    Le test `TEST 14 — REAL LOGIC RESTART` vérifie que lors d'un "restart" conceptuel, la création de `Session 2` depuis un snapshot (donc avec `isRestored: true`) ne déclenche aucune réécriture initiale inutile. La session 2 est recalculée proprement, l'état `chauffer` est validé comme étant `maintained` à nouveau.

14. **Modifications B3 Engine :**
    Aucune modification sur la logique interne de `b3_engine` n'a été effectuée. Seul le mapper lève une exception saine lors de scénarios inexistants (qui existait déjà).

15. **Modifications dataset :**
    Aucune modification n'a été nécessaire sur le dataset.

16. **Résultat dart analyze :**
    `cd packages/b3_engine && dart analyze` ne remonte aucune erreur (No issues found).

17. **Nombre tests engine :**
    Tous les tests métier passent. (Ex: `dart test` valide la non-régression de l'intégralité du moteur).

18. **Résultat flutter analyze :**
    `cd b3_app && flutter analyze` ne retourne aucun avertissement ni erreur de linter (No issues found).

19. **Nombre exact tests Flutter :**
    Tous les tests existants et les 5 nouveaux tests de cette phase réussissent. La suite complète est au vert.

20. **Résultat build Web :**
    La compilation Web via `flutter build web --release` s'est achevée avec succès.

21. **Git status :**
    Le repository est propre, tous les fichiers temporaires et les utilitaires Python ont été ignorés/supprimés. L'état est prêt pour un commit unique propre `fix(flutter): harden local persistence`.

22. **Limitations restantes :**
    La seule limitation MVP persistante est la gestion "silencieuse" des corruptions via `null` (qui réinitialise le foyer en cas de problème de version JSON impossible). Pour les étapes suivantes, nous pourrons potentiellement informer l'utilisateur de cette corruption avec une UI dédiée.
