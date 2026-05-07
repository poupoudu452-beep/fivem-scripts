# Système d'Armes — inv_system v2.0

## Configuration server.cfg

Ajouter ces lignes dans votre `server.cfg` pour activer la commande `/giveweapon` pour les admins :

```cfg
# Autoriser le groupe admin à utiliser /giveweapon
add_ace group.admin command.giveweapon allow

# Ajouter un joueur au groupe admin (remplacer l'identifier)
add_principal identifier.fivem:75db98a3edd3127c15c39a7109e960f6619d7447 group.admin
add_principal identifier.license:75db98a3edd3127c15c39a7109e960f6619d7447 group.admin
```

## Commande /giveweapon

**Usage :** `/giveweapon <ID joueur> <NOM_ARME> [munitions]`

**Exemples :**
```
/giveweapon 1 WEAPON_PISTOL 120
/giveweapon 1 WEAPON_RPG 5
/giveweapon 1 WEAPON_KNIFE
/giveweapon 1 WEAPON_ASSAULTRIFLE 300
```

## Catégories d'armes & Raccourcis

| Touche | Catégorie        | Exemples                                    |
|--------|------------------|---------------------------------------------|
| **1**  | Armes Blanches   | WEAPON_KNIFE, WEAPON_BAT, WEAPON_MACHETE    |
| **2**  | Armes de Poing   | WEAPON_PISTOL, WEAPON_REVOLVER              |
| **3**  | SMG              | WEAPON_SMG, WEAPON_MICROSMG                 |
| **4**  | Fusils           | WEAPON_ASSAULTRIFLE, WEAPON_CARBINERIFLE    |
| **5**  | Fusils à Pompe   | WEAPON_PUMPSHOTGUN, WEAPON_ASSAULTSHOTGUN   |
| **6**  | Snipers          | WEAPON_SNIPERRIFLE, WEAPON_HEAVYSNIPER      |
| **7**  | Armes Lourdes    | WEAPON_RPG, WEAPON_MINIGUN                  |
| **8**  | Lancers          | WEAPON_GRENADE, WEAPON_MOLOTOV              |

## Fonctionnalités

- **Panneau Armes** : Affiché à gauche de l'inventaire quand on ouvre avec TAB
- **Raccourcis 1-8** : Équiper/déséquiper les armes par catégorie (fonctionne hors inventaire)
- **Arme dans le dos** : Les armes lourdes, fusils, snipers et shotguns s'affichent dans le dos du joueur quand elles ne sont pas équipées
- **Clic gauche** sur un slot arme dans l'inventaire : Équiper/déséquiper
- **Clic droit** sur un slot arme dans l'inventaire : Jeter l'arme
- **Roue d'armes désactivée** : Les armes ne peuvent être sorties QUE via les raccourcis 1-8
- **Persistance BDD** : Les armes sont sauvegardées dans la table `character_weapons`

## Fichiers ajoutés/modifiés

### Nouveaux fichiers :
- `shared/weapons.lua` — Définitions de toutes les armes GTA5 + catégories
- `server/weapons.lua` — Commande /giveweapon, gestion serveur, persistance
- `client/weapons.lua` — Raccourcis clavier, équipement, prop dans le dos

### Fichiers modifiés :
- `fxmanifest.lua` — Ajout des nouveaux scripts
- `server/database.lua` — Table `character_weapons`
- `client/main.lua` — Envoi des armes au NUI à l'ouverture
- `html/index.html` — Panneau armes à gauche
- `html/js/app.js` — Rendu des slots armes
- `html/css/style.css` — Styles du panneau armes

## Liste complète des armes

### Armes Blanches (melee)
WEAPON_KNIFE, WEAPON_NIGHTSTICK, WEAPON_HAMMER, WEAPON_BAT, WEAPON_GOLFCLUB, WEAPON_CROWBAR, WEAPON_BOTTLE, WEAPON_DAGGER, WEAPON_HATCHET, WEAPON_MACHETE, WEAPON_SWITCHBLADE, WEAPON_WRENCH, WEAPON_BATTLEAXE, WEAPON_POOLCUE, WEAPON_STONE_HATCHET

### Armes de Poing (handgun)
WEAPON_PISTOL, WEAPON_PISTOL_MK2, WEAPON_COMBATPISTOL, WEAPON_APPISTOL, WEAPON_PISTOL50, WEAPON_SNSPISTOL, WEAPON_SNSPISTOL_MK2, WEAPON_HEAVYPISTOL, WEAPON_VINTAGEPISTOL, WEAPON_MARKSMANPISTOL, WEAPON_REVOLVER, WEAPON_REVOLVER_MK2, WEAPON_DOUBLEACTION, WEAPON_CERAMICPISTOL, WEAPON_NAVYREVOLVER, WEAPON_GADGETPISTOL

### SMG
WEAPON_MICROSMG, WEAPON_SMG, WEAPON_SMG_MK2, WEAPON_ASSAULTSMG, WEAPON_COMBATPDW, WEAPON_MACHINEPISTOL, WEAPON_MINISMG

### Fusils (rifle)
WEAPON_ASSAULTRIFLE, WEAPON_ASSAULTRIFLE_MK2, WEAPON_CARBINERIFLE, WEAPON_CARBINERIFLE_MK2, WEAPON_ADVANCEDRIFLE, WEAPON_SPECIALCARBINE, WEAPON_SPECIALCARBINE_MK2, WEAPON_BULLPUPRIFLE, WEAPON_BULLPUPRIFLE_MK2, WEAPON_COMPACTRIFLE, WEAPON_MILITARYRIFLE, WEAPON_HEAVYRIFLE, WEAPON_TACTICALRIFLE

### Fusils à Pompe (shotgun)
WEAPON_PUMPSHOTGUN, WEAPON_PUMPSHOTGUN_MK2, WEAPON_SAWNOFFSHOTGUN, WEAPON_ASSAULTSHOTGUN, WEAPON_BULLPUPSHOTGUN, WEAPON_MUSKET, WEAPON_HEAVYSHOTGUN, WEAPON_DBSHOTGUN, WEAPON_AUTOSHOTGUN, WEAPON_COMBATSHOTGUN

### Snipers
WEAPON_SNIPERRIFLE, WEAPON_HEAVYSNIPER, WEAPON_HEAVYSNIPER_MK2, WEAPON_MARKSMANRIFLE, WEAPON_MARKSMANRIFLE_MK2, WEAPON_PRECISIONRIFLE

### Armes Lourdes (heavy)
WEAPON_RPG, WEAPON_GRENADELAUNCHER, WEAPON_MINIGUN, WEAPON_FIREWORK, WEAPON_RAILGUN, WEAPON_HOMINGLAUNCHER, WEAPON_COMPACTLAUNCHER

### Lancers (thrown)
WEAPON_GRENADE, WEAPON_BZGAS, WEAPON_SMOKEGRENADE, WEAPON_MOLOTOV, WEAPON_STICKYBOMB, WEAPON_PROXMINE, WEAPON_PIPEBOMB, WEAPON_FLARE
