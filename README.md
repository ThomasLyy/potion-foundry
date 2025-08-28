# Potion Foundry — Starter (Godot 4.x)

1) Crée un projet Godot 4.x vide.
2) Copie `data/` et `scripts/` à la racine du projet.
3) Project > Project Settings > Autoload :
   - `scripts/Data.gd` → `Data`
   - `scripts/GameController.gd` → `GameController`
   - `scripts/SaveManager.gd` → `SaveManager`
4) Crée une scène `Main.tscn` avec un Node et un Label :
   - Dans `_process(delta)`, appelle `GameController.tick(delta)`
   - Mets à jour le Label avec `str(round(GameController.state.ecu)) + " ₠"`

Notes : 
- `recipes.json` contient 12 recettes (coûts, prix, fenêtre Temp via `twin`, palier Pureté).
- Les formules de qualité et de prestige sont implémentées et ajustables dans `GameController.gd`.
