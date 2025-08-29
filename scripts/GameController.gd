extends Node
# ========================================================================
#  GameController.gd
#  - Gère l'état global du jeu, la production et le brassage auto
#  - Auto-craft désactivé tant que UAA == 0 (se réactive à UAA >= 1)
#  - Les formules restent en float, mais on crédite/débite en ENTIER
# ========================================================================

# === SECTION: ÉTAT GLOBAL =================================================
var state: Dictionary = {}

func _ready():
	if state.is_empty():
		state = _default_state()

func _default_state() -> Dictionary:
	return {
		"ecu": 0.0,
		"lifetime_ecu": 0.0,
		"seals": 0,
		"stock": { "F": 0.0, "E": 0.0, "A": 0.0 },
		"prod":  { "F": 0.0, "E": 0.0, "A": 0.0 },
		"buildings": {},          # "DF","CE","EA","AA" -> int
		"upgrades": {},           # "UAA","UP","UPUR", ("UF","UE","UA" si tu en ajoutes plus tard)
		"current_recipe": "R1",
		"current_temp": 650.0,
		# === SECTION EXT: ONBOARDING / FLAGS (Main.gd peut écrire ici) ===
		"onb_step": 0,
		# === SECTION EXT: RECIPES UNLOCKS =================================
		"recipes_unlocked": { "R1": true, "R2": false, "R3": false },
		# === SECTION EXT: ACHIEVEMENTS ====================================
		"achievements": {},   # ex: { "first_df": true, "auto_on": true, ... }
	}

# === SECTION: UTILS ÉCONOMIE =============================================
# Points d’extension : si tu ajoutes de nouvelles upgrades, étends ici.
func get_upgrade_level(id: String) -> int:
	return int(state.upgrades.get(id, 0))

func _auto_craft_enabled() -> bool:
	return get_upgrade_level("UAA") >= 1

# Vitesse de craft (temps par craft) — influence UAA (min 0.25 s)
func _t_craft() -> float:
	var level := float(get_upgrade_level("UAA"))
	return max(1.0 * pow(0.9, level), 0.25)

# Multiplicateur de qualité en fonction de la température et pureté
func _quality_mult(recipe: Dictionary) -> float:
	if recipe.is_empty(): return 1.0
	var t_opt: float = 0.5 * (float(recipe["twin"][0]) + float(recipe["twin"][1]))
	var mult_temp: float = 1.0 - clamp(abs(state.current_temp - t_opt) / 100.0, 0.0, 0.30)

	var purity_tier: int = min(3, get_upgrade_level("UPUR"))
	var mult_purity: float = 1.0 + 0.05 * float(purity_tier)

	# Malus si trop rapide (< 0.33 s)
	var malus: float = 0.0
	var tc: float = _t_craft()
	if tc < 0.33:
		malus = min(0.10, 0.02 * ((0.33 / tc) - 1.0))

	return mult_temp * mult_purity * (1.0 - malus)

func _price_per_craft(recipe: Dictionary) -> float:
	var base: float = float(recipe["price"])
	var mult_price: float = pow(1.1, float(get_upgrade_level("UP")))
	var mult_seals: float = pow(1.08, float(state.seals))
	return base * _quality_mult(recipe) * mult_price * mult_seals

# === SECTION: PRODUCTION ==================================================
const BASE_PROD_PER_BUILDING := 0.1  # F/E/A par seconde et par bâtiment (DF/CE/EA)

func _recompute_prod():
	var df := int(state.buildings.get("DF", 0))
	var ce := int(state.buildings.get("CE", 0))
	var ea := int(state.buildings.get("EA", 0))

	# Upgrades spécifiques ressource (si un jour tu ajoutes UF/UE/UA, ça fonctionnera déjà)
	var multF := pow(1.2, float(get_upgrade_level("UF")))
	var multE := pow(1.2, float(get_upgrade_level("UE")))
	var multA := pow(1.2, float(get_upgrade_level("UA")))

	state.prod["F"] = float(df) * BASE_PROD_PER_BUILDING * multF
	state.prod["E"] = float(ce) * BASE_PROD_PER_BUILDING * multE
	state.prod["A"] = float(ea) * BASE_PROD_PER_BUILDING * multA

# === SECTION: CRAFT AUTO (garde UAA) =====================================
var _craft_accum: float = 0.0

func _can_pay_recipe(recipe: Dictionary) -> bool:
	for k in recipe["cost"].keys():
		var need_i := int(round(float(recipe["cost"][k])))
		if int(floor(float(state.stock.get(k, 0.0)))) < need_i:
			return false
	return true

func _consume_recipe(recipe: Dictionary, times: int) -> void:
	for k in recipe["cost"].keys():
		var need := int(round(float(recipe["cost"][k]))) * times
		var cur := int(round(float(state.stock.get(k, 0.0))))
		state.stock[k] = max(0.0, float(cur - need))

func _try_craft_once() -> bool:
	var r: Dictionary = Data.get_recipe(str(state.current_recipe))
	if r.is_empty(): return false
	if not _can_pay_recipe(r): return false

	_consume_recipe(r, 1)
	var gain := int(round(_price_per_craft(r)))
	state.ecu = float(int(round(state.ecu)) + gain)
	state.lifetime_ecu = float(int(round(state.lifetime_ecu)) + gain)
	return true

# === SECTION: TICK GLOBAL (appelé par Main.gd chaque frame) ==============
func tick(delta: float) -> void:
	# 1) Production passive
	_recompute_prod()
	state.stock["F"] += state.prod["F"] * delta
	state.stock["E"] += state.prod["E"] * delta
	state.stock["A"] += state.prod["A"] * delta

	# 2) Brassage automatique (seulement si UAA >= 1)
	if _auto_craft_enabled():
		_craft_accum += delta
		var tc := _t_craft()
		while _craft_accum >= tc:
			_craft_accum -= tc
			if not _try_craft_once():
				# Si on ne peut plus payer, on casse la boucle
				break
