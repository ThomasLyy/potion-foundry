Voici un **README.md** prêt à coller à la racine du repo.

---

# Potion Foundry — Cycles des Essences

Petit jeu **idle / incremental** réalisé sous **Godot 4**.
Le joueur distille **Feu (F)**, **Eau (E)** et **Air (A)** pour brasser des potions selon des **recettes**. On commence par cliquer pour produire manuellement, puis on automatise via des bâtiments et on améliore via des upgrades.

> Univers & intentions de design issus du projet **Cycles des Essences**.

---

## ✨ Fonctionnalités

* **Production manuelle** (+F / +E / +A) pour démarrer la boucle.
* **Bâtiments** (DF/CE/EA/AA) avec **coûts progressifs** (suite géométrique).
* **Upgrades** : Vitesse d’atelier, Prix de vente, Pureté (capée).
* **Sélecteur de recette** (R1 → R3) + **prix estimé / craft** dynamique (température, pureté, vitesse, bonus prix).
* **Quantités d’achat** ×1 / ×10 / ×Max (pour bâtiments & upgrades).
* **Autosave** toutes les 60 s **et à la fermeture** ; **auto-load** au lancement.
  → Pas d’offline sur PC : on retrouve **exactement** l’état laissé.
* **Boucle économe** : simulation & rafraîchissement UI **10 Hz** (CPU friendly).

---

## 🎮 Boucle de jeu

1. **Cliquer** (+F) pour accumuler la première essence.
2. **Acheter** 1 **Distillateur de Feu (DF)** → la production automatique démarre.
3. **Brasser** des potions selon la recette sélectionnée (tourne en fond).
4. **Étendre** (bâtiments) et **améliorer** (upgrades) pour accélérer la progression.

---

## ⌨️ Contrôles

* **Manuel** : `+F` / `+E` / `+A` via boutons (ou **J / K / L** au clavier).
* **Achat bâtiments** : **Q / W / E / R** (DF / CE / EA / AA).
* **Achat upgrades** : **A / S / D** (UAA / UP / UPUR).
* **Quantité d’achat (bâtiments)** : **1 / 2 / 3** → ×1 / ×10 / ×Max.
* **Quantité d’achat (upgrades)** : **4 / 5 / 6** → ×1 / ×10 / ×Max.
* **Température** : slider (affecte la qualité/prix estimé).
* (Option dev) **Prestige** : **P** (si activé dans le script).

---

## 🛠️ Installation & lancement

1. Installer **Godot 4.x** (Stable).
2. Cloner le repo puis **Open Project** depuis Godot (fichier `project.godot`).
3. **F5** pour lancer.

### Réglages performance recommandés (Project Settings)

* **Display → Window → V-Sync** : `Use V-Sync = On`.
* **Application → Run → Low Processor Mode = On** (+ `Sleep 20000–33000 usec`).
* (Option) **Max FPS = 60**.

---

## 🗂️ Structure du projet

```
.
├── data/
│   ├── buildings.json        # définitions des bâtiments (id, cost0, r, …)
│   ├── upgrades.json         # upgrades (id, cost0, r, max, …)
│   ├── recipes.json          # recettes (id, name, cost{F,E,A}, price, twin, …)
│   └── manifest_univers.json # méta, textes, références d’univers
├── scenes/
│   └── Main.tscn             # scène principale (UI)
├── scripts/
│   ├── Main.gd               # logique UI & gameplay de surface
│   ├── GameController.gd     # simulation, tick, état du jeu
│   ├── Data.gd               # chargement/accès aux JSON
│   └── SaveManager.gd        # save/load user://
├── project.godot
└── .gitignore
```

---

## 📦 Données (formats)

### Bâtiments (`data/buildings.json`)

```json
[
  { "id": "DF", "name": "Distillateur de Feu", "cost0": 15.0, "r": 1.15 },
  { "id": "CE", "name": "Condenseur d’Eau",   "cost0": 15.0, "r": 1.15 },
  { "id": "EA", "name": "Éoliseur d’Air",     "cost0": 15.0, "r": 1.15 },
  { "id": "AA", "name": "Atelier d’Alchimie", "cost0": 56.0, "r": 1.15 }
]
```

> Coût de la **k-ième** unité à partir de n : `cost0 * r^(n)`, coût d’un lot via somme géométrique.

### Upgrades (`data/upgrades.json`)

```json
[
  { "id": "UAA",  "name": "Vitesse Atelier", "cost0": 100, "r": 1.25 },
  { "id": "UP",   "name": "Prix Potions",    "cost0": 120, "r": 1.25 },
  { "id": "UPUR", "name": "Pureté",          "cost0": 200, "r": 1.35, "max": 3 }
]
```

### Recettes (`data/recipes.json`)

```json
[
  {
    "id": "R1",
    "name": "Flamme Douce",
    "cost": { "F": 1.0, "E": 0.0, "A": 0.0 },
    "price": 10.0,
    "twin": [600, 700]        // plage de T optimale (influence la qualité/prix)
  }
]
```

---

## 💾 Sauvegarde

* **Autosave** toutes les **60 s** et **à la fermeture**.
* **Auto-load** au démarrage si un fichier existe (`user://save.json`).
* **Pas d’offline** : aucune progression n’est simulée pendant l’arrêt.
* On retrouve **l’exact état** laissé à la fermeture.

---

## 🧮 Économie (résumé)

* **Production** F/E/A = somme des bâtiments concernés × base × upgrades.
* **Craft** en continu selon la recette sélectionnée (consomme F/E/A).
* **Prix estimé / craft** = `price_base × qualité(temp) × pureté × (1 − malus_vitesse) × bonus_prix × bonus_sceaux`.
* **Coûts progressifs** (bâtiments & upgrades) via ratio `r`.
* **×Max** calcule une quantité achetable en fermant la formule géométrique.

---

## 🧪 Raccourcis développeur (utiles en test)

* **J/K/L** : +F / +E / +A
* **Q/W/E/R** : acheter DF / CE / EA / AA
* **A/S/D** : acheter UAA / UP / UPUR
* **1/2/3** : mode d’achat bâtiments ×1/×10/×Max
* **4/5/6** : mode d’achat upgrades ×1/×10/×Max
* **P** : tentative de **Prestige** (si la fonction est activée dans `Main.gd`)

---

## 🚧 Roadmap (prochaines étapes)

* **Onboarding** (3 étapes) & **déblocage progressif** (E/A, upgrades).
* **Bouton “Brasser 1x maintenant”** (craft instant si ressources ok).
* **Succès** et **jalons** (balises de progression).
* **Thème visuel** & assets (polish UI/UX, animations légères).
* **Options** (remapping des touches, volume, FPS cap).

---

## 🤝 Contribuer

* **Conventional Commits** recommandés.
* PR petites et atomiques (1 feature / 1 bugfix).
* Fichiers générés Godot ignorés (`.import/`, `.godot/`).

### Routine de fin de session (rappel)

```bash
git add -A
git commit -m "feat(ui): buy panel + temp slider; fix(gd): round helper; chore(layout): wiring"
git push
# si jalon :
git tag -a v0.X.Y -m "session: <résumé court>"
git push origin v0.X.Y
```

---

## 📜 Licence

À définir.

---

## 🙏 Crédits

* Game design / dev : **Potion Foundry** (projet **Cycles des Essences**).
* Moteur : **Godot 4**.
* Merci aux testeurs pour les retours itératifs.

---

