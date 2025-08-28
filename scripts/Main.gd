extends Node

# ---------- RÉFÉRENCES UI (HEADER / TEMP / RECETTE) ----------
@onready var money_label: Label = $Layout/Header/StocksRow/MoneyLabel
@onready var f_label: Label = $Layout/Header/StocksRow/FLabel
@onready var e_label: Label = $Layout/Header/StocksRow/ELabel
@onready var a_label: Label = $Layout/Header/StocksRow/ALabel
@onready var fprod_label: Label = $Layout/Header/ProdRow/FProdLabel
@onready var eprod_label: Label = $Layout/Header/ProdRow/EProdLabel
@onready var aprod_label: Label = $Layout/Header/ProdRow/AProdLabel

@onready var temp_slider: HSlider = $Layout/TempRow/TempSlider
@onready var temp_value: Label = $Layout/TempRow/TempValue

@onready var recipe_info: Label = $Layout/RecipeRow/RecipeInfo
# (RecipeSelect sera récupéré de façon robuste dans _ready)

@onready var addf_btn: Button = $Layout/ManualRow/AddFBtn
@onready var adde_btn: Button = $Layout/ManualRow/AddEBtn
@onready var adda_btn: Button = $Layout/ManualRow/AddABtn

# ---------- RÉFÉRENCES UI (BÂTIMENTS / ACHATS) ----------
@onready var df_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFName
@onready var ce_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CEName
@onready var ea_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EAName
@onready var aa_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AAName

@onready var df_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFCost
@onready var ce_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CECost
@onready var ea_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EACost
@onready var aa_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AACost
# (BuyMode sera récupéré de façon robuste dans _ready)

# ---------- REFERENCES BOUTONS ----------
@onready var df_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFBuy
@onready var ce_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CEBuy
@onready var ea_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EABuy
@onready var aa_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AABuy

@onready var uaa_buy: Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAABuy
@onready var up_buy:  Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPBuy
@onready var upur_buy: Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURBuy


# ---------- RÉFÉRENCES UI (UPGRADES) ----------
@onready var uaa_name: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAAName
@onready var uaa_cost: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAACost
@onready var up_name:  Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPName
@onready var up_cost:  Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPCost
@onready var upur_name: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURName
@onready var upur_cost: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURCost
# (UpgradeMode sera récupéré de façon robuste dans _ready)

# ---------- PERF & AUTOSAVE ----------
const CLICK_F: float = 0.25
const CLICK_E: float = 0.25
const CLICK_A: float = 0.25

const SIM_DT: float = 0.10          # Simulation 10 Hz (économe CPU)
const UI_DT:  float = 0.10          # Refresh UI 10 Hz
const AUTOSAVE_EVERY: float = 60.0  # Autosave toutes les 60s

var _sim_accum: float = 0.0
var _ui_accum: float = 0.0
var _autosave_accum: float = 0.0
var _did_save_on_exit: bool = false

# OptionButtons (récupérés proprement dans _ready)
var buy_mode_btn: OptionButton = null
var recipe_select_btn: OptionButton = null
var upgrade_mode_btn: OptionButton = null

# Fallback si OptionButton absent
var buy_mode_selected: int = 0
var upgrade_mode_selected: int = 0

# ---------- UTILS ----------
func fmt2(x) -> String:
	return str(round(float(x) * 100.0) / 100.0)

func _upgrade_level(key: String) -> int:
	var u: Dictionary = GameController.state.upgrades
	return int(u.get(key, 0))

func _craft_time() -> float:
	var level: int = _upgrade_level("UAA")
	return max(1.0 * pow(0.9, float(level)), 0.25)
	
# ---------- HELPERS ---------
func _can_pay(total: float) -> bool:
	return GameController.state.ecu >= total - 0.000001

func _tooltip_cost_single(id: String, start_count: int) -> String:
	# coût de la prochaine unité (×1)
	var c := building_cost(id, start_count)
	return "Prochaine unité: " + fmt2(c) + " ₠"
	
func _seals_gainable() -> int:
	# 1 sceau par palier de 1000 ₠ gagnés à vie (lifetime_ecu)
	var gained_so_far: int = int(GameController.state.seals)
	var potential: int = int(floor(GameController.state.lifetime_ecu / 1000.0))
	return max(0, potential - gained_so_far)

func _next_seal_threshold() -> float:
	# Prochain palier (en ₠) pour obtenir +1 sceau
	var next_index: int = int(GameController.state.seals) + 1
	return 1000.0 * float(next_index)

func _do_prestige_if_possible() -> void:
	var gain: int = _seals_gainable()
	if gain <= 0:
		var need: float = _next_seal_threshold() - float(GameController.state.lifetime_ecu)
		need = max(0.0, need)
		print("[Prestige] Pas encore disponible — manque ", fmt2(need), " ₠ de lifetime.")
		return

	# Applique le prestige : ajoute les sceaux et réinitialise le run
	GameController.state.seals = int(GameController.state.seals) + gain

	# Reset "run" (on garde lifetime_ecu et les sceaux)
	GameController.state.ecu = 0.0
	GameController.state.stock = {"F": 0.0, "E": 0.0, "A": 0.0}
	GameController.state.buildings = {}
	GameController.state.upgrades = {}
	# On garde la recette et la température actuelles
	# GameController.state.current_recipe, GameController.state.current_temp inchangés

	print("[Prestige] +", gain, " sceau(x). Total: ", GameController.state.seals)
	_refresh_all()
	_do_save(false)
	
func _manual_gain(res: String, base_amount: float) -> void:
	# Les upgrades UF/UE/UA boostent aussi le clic manuel (même logique que la prod)
	var mult: float = pow(1.2, float(_upgrade_level("U" + res)))
	GameController.state.stock[res] += base_amount * mult


# ---------- BÂTIMENTS : coûts / quantités ----------
func building_cost(id: String, count: int) -> float:
	var b: Dictionary = Data.get_building(id)
	if b.is_empty(): return 0.0
	var cost0: float = float(b["cost0"])
	var r: float = float(b["r"])
	return cost0 * pow(r, float(count))

func building_bulk_cost(id: String, start_count: int, k: int) -> float:
	if k <= 0: return 0.0
	var b: Dictionary = Data.get_building(id)
	if b.is_empty(): return 0.0
	var cost0: float = float(b["cost0"])
	var r: float = float(b["r"])
	if abs(r - 1.0) < 0.000001:
		return cost0 * float(k)
	return cost0 * pow(r, float(start_count)) * (pow(r, float(k)) - 1.0) / (r - 1.0)

func max_affordable_qty(id: String, start_count: int, budget: float) -> int:
	var b: Dictionary = Data.get_building(id)
	if b.is_empty() or budget <= 0.0: return 0
	var cost0: float = float(b["cost0"])
	var r: float = float(b["r"])
	if abs(r - 1.0) < 0.000001: return int(floor(budget / cost0))
	var denom: float = cost0 * pow(r, float(start_count))
	var inside: float = 1.0 + (r - 1.0) * (budget / max(denom, 0.000001))
	if inside <= 1.000001: return 0
	return int(floor(log(inside) / log(r)))

func owned_text(base_name: String, n: int) -> String:
	return "%s — x%d" % [base_name, n]

func current_buy_qty(id: String) -> int:
	var b: Dictionary = GameController.state.buildings
	var n: int = int(b.get(id, 0))
	var sel: int = buy_mode_selected
	if buy_mode_btn:
		sel = buy_mode_btn.selected
	match sel:
		0: return 1
		1: return 10
		2: return max_affordable_qty(id, n, float(GameController.state.ecu))
		_: return 1

# ---------- UPGRADES : coûts / quantités ----------
func upgrade_cost(id: String, level: int) -> float:
	var u: Dictionary = Data.get_upgrade(id)
	if u.is_empty(): return 0.0
	var cost0: float = float(u["cost0"])
	var r: float = float(u["r"])
	return cost0 * pow(r, float(level))

func upgrade_bulk_cost(id: String, start_level: int, k: int) -> float:
	if k <= 0: return 0.0
	var u: Dictionary = Data.get_upgrade(id)
	if u.is_empty(): return 0.0
	var max_level: int = int(u.get("max", 999999))
	var allowed: int = min(k, max_level - start_level)
	if allowed <= 0: return 0.0
	var cost0: float = float(u["cost0"])
	var r: float = float(u["r"])
	if abs(r - 1.0) < 0.000001:
		return cost0 * float(allowed)
	return cost0 * pow(r, float(start_level)) * (pow(r, float(allowed)) - 1.0) / (r - 1.0)

func max_affordable_qty_upgrade(id: String, start_level: int, budget: float) -> int:
	var u: Dictionary = Data.get_upgrade(id)
	if u.is_empty() or budget <= 0.0: return 0
	var max_level: int = int(u.get("max", 999999))
	var remaining: int = max(0, max_level - start_level)
	if remaining <= 0: return 0
	var cost0: float = float(u["cost0"])
	var r: float = float(u["r"])
	if abs(r - 1.0) < 0.000001:
		return min(int(floor(budget / cost0)), remaining)
	var denom: float = cost0 * pow(r, float(start_level))
	var inside: float = 1.0 + (r - 1.0) * (budget / max(denom, 0.000001))
	if inside <= 1.000001: return 0
	return min(int(floor(log(inside) / log(r))), remaining)

func current_upgrade_qty(id: String) -> int:
	var lvl: int = _upgrade_level(id)
	var sel: int = upgrade_mode_selected
	if upgrade_mode_btn:
		sel = upgrade_mode_btn.selected
	match sel:
		0: return 1
		1: return 10
		2: return max_affordable_qty_upgrade(id, lvl, float(GameController.state.ecu))
		_: return 1

# ---------- ESTIMÉ PRIX / CRAFT ----------
func _price_estimate(recipe: Dictionary) -> float:
	if recipe.is_empty(): return 0.0
	var base_price: float = float(recipe["price"])
	var t_opt: float = 0.5 * (float(recipe["twin"][0]) + float(recipe["twin"][1]))
	var mult_temp: float = 1.0 - clamp(abs(GameController.state.current_temp - t_opt) / 100.0, 0.0, 0.30)
	var purity_tier: int = min(3, _upgrade_level("UPUR"))
	var mult_purity: float = 1.0 + 0.05 * float(purity_tier)
	var malus: float = 0.0
	var tc: float = _craft_time()
	if tc < 0.33: malus = min(0.10, 0.02 * ((0.33 / tc) - 1.0))
	var mult_price: float = pow(1.1, float(_upgrade_level("UP")))
	var mult_seals: float = pow(1.08, float(GameController.state.seals))
	return base_price * mult_temp * mult_purity * (1.0 - malus) * mult_price * mult_seals

# ---------- SAUVEGARDE (SANS OFFLINE) ----------
func _do_save(show_log: bool = false) -> void:
	SaveManager.save(GameController.state)
	if show_log:
		print("Sauvegardé.")

func _do_load_or_init() -> void:
	var loaded: Dictionary = SaveManager.load_state()
	if loaded.is_empty():
		GameController.state.current_recipe = "R1"
		GameController.state.current_temp = 650.0
	else:
		GameController.state = loaded
	# MAJ UI selon l'état chargé
	if temp_slider:
		temp_slider.value = float(GameController.state.current_temp)
	if temp_value:
		temp_value.text = str(int(GameController.state.current_temp))

	_refresh_all()
	
	print("Loaded. Seals=", GameController.state.seals,
	  " | Lifetime ₠=", fmt2(float(GameController.state.lifetime_ecu)))

func _exit_tree() -> void:
	if not _did_save_on_exit:
		_did_save_on_exit = true
		_do_save(false)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _did_save_on_exit:
			_did_save_on_exit = true
			_do_save(false)
		get_tree().quit()

# ---------- READY ----------
func _ready():
	# Récupère les OptionButtons proprement (avec ou sans Layout/BuyBody/UpBody)
	buy_mode_btn = _find_option_button([
		"Layout/BuyPanel/BuyMargin/BuyBody/BuyToolbar/BuyMode",
		"BuyPanel/BuyMargin/BuyBody/BuyToolbar/BuyMode",
		"%BuyMode"
	])
	if buy_mode_btn:
		buy_mode_btn.select(0)
		if not buy_mode_btn.is_connected("item_selected", Callable(self, "_on_BuyMode_item_selected")):
			buy_mode_btn.connect("item_selected", Callable(self, "_on_BuyMode_item_selected"))

	recipe_select_btn = _find_option_button([
		"Layout/RecipeRow/RecipeSelect",
		"RecipeRow/RecipeSelect",
		"%RecipeSelect"
	])
	if recipe_select_btn:
		if recipe_select_btn.item_count == 0:
			var ids: Array[String] = ["R1","R2","R3"]
			for i in range(ids.size()):
				var r: Dictionary = Data.get_recipe(ids[i])
				var label: String = ids[i]
				if not r.is_empty():
					label = "%s — %s" % [ids[i], str(r["name"])]
				recipe_select_btn.add_item(label, i)
		recipe_select_btn.select(0)
		if not recipe_select_btn.is_connected("item_selected", Callable(self, "_on_RecipeSelect_item_selected")):
			recipe_select_btn.connect("item_selected", Callable(self, "_on_RecipeSelect_item_selected"))

	upgrade_mode_btn = _find_option_button([
		"Layout/UpgradesPanel/UpMargin/UpBody/UpToolbar/UpgradeMode",
		"UpgradesPanel/UpMargin/UpBody/UpToolbar/UpgradeMode",
		"%UpgradeMode"
	])
	if upgrade_mode_btn:
		upgrade_mode_btn.select(0)
		if not upgrade_mode_btn.is_connected("item_selected", Callable(self, "_on_UpgradeMode_item_selected")):
			upgrade_mode_btn.connect("item_selected", Callable(self, "_on_UpgradeMode_item_selected"))

	_do_load_or_init()

# Cherche un OptionButton parmi plusieurs chemins possibles
func _find_option_button(candidates: Array[String]) -> OptionButton:
	for p in candidates:
		var n: Node = get_node_or_null(p)
		if n != null:
			return n as OptionButton
	return null

# ---------- PROCESS (économe) ----------
func _process(delta):
	# Simulation 10 Hz
	_sim_accum += delta
	while _sim_accum >= SIM_DT:
		GameController.tick(SIM_DT)
		_sim_accum -= SIM_DT

	# Sync température (même si le signal n'est pas branché)
	if temp_slider:
		var v: float = float(temp_slider.value)
		if v != GameController.state.current_temp:
			GameController.state.current_temp = v
			if temp_value: temp_value.text = str(int(v))
			_update_recipe_info()

	# UI 10 Hz
	_ui_accum += delta
	if _ui_accum >= UI_DT:
		_ui_accum = 0.0
		_refresh_runtime()
		_refresh_costs()
		_refresh_upgrades_costs()

	# Autosave léger
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_EVERY:
		_autosave_accum = 0.0
		_do_save(false)

# ---------- REFRESH UI ----------
func _refresh_runtime():
	money_label.text = str(int(round(GameController.state.ecu))) + " ₠"

	var s = GameController.state.stock
	f_label.text = "F: " + fmt2(s["F"])
	e_label.text = "E: " + fmt2(s["E"])
	a_label.text = "A: " + fmt2(s["A"])

	var p = GameController.state.prod
	fprod_label.text = "F/s: " + fmt2(p["F"])
	eprod_label.text = "E/s: " + fmt2(p["E"])
	aprod_label.text = "A/s: " + fmt2(p["A"])

	var b: Dictionary = GameController.state.buildings
	df_name.text = owned_text("Distillateur de Feu (DF)", int(b.get("DF", 0)))
	ce_name.text = owned_text("Condenseur d’Eau (CE)", int(b.get("CE", 0)))
	ea_name.text = owned_text("Éoliseur d’Air (EA)", int(b.get("EA", 0)))
	aa_name.text = owned_text("Atelier d’Alchimie (AA)", int(b.get("AA", 0)))

	_update_recipe_info()
	_refresh_upgrades_runtime()

func _update_recipe_info():
	var rid: String = str(GameController.state.current_recipe)
	var r: Dictionary = Data.get_recipe(rid)
	if r.is_empty():
		recipe_info.text = ""
		return
	var costs: Array[String] = []
	for k in r["cost"].keys():
		costs.append("%s:%s" % [str(k), str(r["cost"][k])])
	var cost_str: String = "Coût " + ", ".join(costs)
	var price: float = float(r["price"])
	var est: float = _price_estimate(r)
	recipe_info.text = "%s | Prix base: %s ₠ | Estimé/craft: %s ₠" % [cost_str, fmt2(price), fmt2(est)]

func _refresh_costs():
	var b: Dictionary = GameController.state.buildings
	var n_df: int = int(b.get("DF", 0))
	var n_ce: int = int(b.get("CE", 0))
	var n_ea: int = int(b.get("EA", 0))
	var n_aa: int = int(b.get("AA", 0))

	var qdf: int = current_buy_qty("DF")
	var qce: int = current_buy_qty("CE")
	var qea: int = current_buy_qty("EA")
	var qaa: int = current_buy_qty("AA")

	var t_df := building_bulk_cost("DF", n_df, qdf)
	var t_ce := building_bulk_cost("CE", n_ce, qce)
	var t_ea := building_bulk_cost("EA", n_ea, qea)
	var t_aa := building_bulk_cost("AA", n_aa, qaa)

	df_cost.text = "Coût: %s ₠ (×%d)" % [fmt2(t_df), qdf]
	ce_cost.text = "Coût: %s ₠ (×%d)" % [fmt2(t_ce), qce]
	ea_cost.text = "Coût: %s ₠ (×%d)" % [fmt2(t_ea), qea]
	aa_cost.text = "Coût: %s ₠ (×%d)" % [fmt2(t_aa), qaa]

	if df_buy:
		df_buy.disabled = not _can_pay(t_df) or qdf <= 0
		df_buy.tooltip_text = _tooltip_cost_single("DF", n_df)
	if ce_buy:
		ce_buy.disabled = not _can_pay(t_ce) or qce <= 0
		ce_buy.tooltip_text = _tooltip_cost_single("CE", n_ce)
	if ea_buy:
		ea_buy.disabled = not _can_pay(t_ea) or qea <= 0
		ea_buy.tooltip_text = _tooltip_cost_single("EA", n_ea)
	if aa_buy:
		aa_buy.disabled = not _can_pay(t_aa) or qaa <= 0
		aa_buy.tooltip_text = _tooltip_cost_single("AA", n_aa)


func _refresh_upgrades_runtime():
	uaa_name.text = "Vitesse Atelier (UAA) — L" + str(_upgrade_level("UAA"))
	up_name.text  = "Prix Potions (UP) — L" + str(_upgrade_level("UP"))
	var lvl_pu: int = _upgrade_level("UPUR")
	var max_pu: int = int(Data.get_upgrade("UPUR").get("max", 3))
	upur_name.text = "Pureté (UPUR) — L%s/%s" % [str(lvl_pu), str(max_pu)]

func _refresh_upgrades_costs():
	var l_uaa: int = _upgrade_level("UAA")
	var l_up:  int = _upgrade_level("UP")
	var l_pur: int = _upgrade_level("UPUR")

	var q_uaa: int = current_upgrade_qty("UAA")
	var q_up:  int = current_upgrade_qty("UP")
	var q_pur: int = current_upgrade_qty("UPUR")

	var t_uaa := upgrade_bulk_cost("UAA", l_uaa, q_uaa)
	var t_up  := upgrade_bulk_cost("UP",  l_up,  q_up)
	var t_pur := upgrade_bulk_cost("UPUR",l_pur, q_pur)

	uaa_cost.text = "Coût: %s ₠ (×%d)" % [fmt2(t_uaa), q_uaa]
	up_cost.text  = "Coût: %s ₠ (×%d)" % [fmt2(t_up),  q_up]
	upur_cost.text= "Coût: %s ₠ (×%d)" % [fmt2(t_pur), q_pur]

	# Désactivation + tooltip cap max
	var max_pur: int = int(Data.get_upgrade("UPUR").get("max", 3))
	if uaa_buy:
		uaa_buy.disabled = not _can_pay(t_uaa) or q_uaa <= 0
	if up_buy:
		up_buy.disabled  = not _can_pay(t_up)  or q_up  <= 0
	if upur_buy:
		var capped := (l_pur >= max_pur)
		upur_buy.disabled = capped or not _can_pay(t_pur) or q_pur <= 0
		if capped:
			upur_buy.tooltip_text = "Niveau max atteint (%d)" % max_pur
		else:
			upur_buy.tooltip_text = ""


func _refresh_all():
	_refresh_runtime()
	_refresh_costs()
	_refresh_upgrades_runtime()
	_refresh_upgrades_costs()

# ---------- ACHATS ----------
func _buy_building(id: String):
	var b: Dictionary = GameController.state.buildings
	var n: int = int(b.get(id, 0))
	var q: int = current_buy_qty(id)
	if q <= 0: return
	var total: float = building_bulk_cost(id, n, q)
	if GameController.state.ecu >= total:
		GameController.state.ecu -= total
		b[id] = n + q
		_refresh_costs()

func _buy_upgrade(id: String):
	var lvl: int = _upgrade_level(id)
	var q: int = current_upgrade_qty(id)
	if q <= 0: return
	var total: float = upgrade_bulk_cost(id, lvl, q)
	if GameController.state.ecu >= total:
		GameController.state.ecu -= total
		GameController.state.upgrades[id] = lvl + q
		_refresh_upgrades_runtime()
		_refresh_upgrades_costs()
		_update_recipe_info()

func _select_buy_mode(i: int) -> void:
	buy_mode_selected = clamp(i, 0, 2)
	if buy_mode_btn:
		buy_mode_btn.select(buy_mode_selected)
	_refresh_costs()

func _select_upgrade_mode(i: int) -> void:
	upgrade_mode_selected = clamp(i, 0, 2)
	if upgrade_mode_btn:
		upgrade_mode_btn.select(upgrade_mode_selected)
	_refresh_upgrades_costs()
	
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# Modes d'achat bâtiments
			Key.KEY_1: _select_buy_mode(0)   # ×1
			Key.KEY_2: _select_buy_mode(1)   # ×10
			Key.KEY_3: _select_buy_mode(2)   # ×Max

			# Modes d'achat upgrades
			Key.KEY_4: _select_upgrade_mode(0)  # ×1
			Key.KEY_5: _select_upgrade_mode(1)  # ×10
			Key.KEY_6: _select_upgrade_mode(2)  # ×Max

			# Achats rapides (bâtiments)
			Key.KEY_Q: _buy_building("DF")
			Key.KEY_W: _buy_building("CE")
			Key.KEY_E: _buy_building("EA")
			Key.KEY_R: _buy_building("AA")

			# Achats rapides (upgrades)
			Key.KEY_A: _buy_upgrade("UAA")
			Key.KEY_S: _buy_upgrade("UP")
			Key.KEY_D: _buy_upgrade("UPUR")
			
			# Manual
			Key.KEY_J: _manual_gain("F", CLICK_F)  # +F
			Key.KEY_K: _manual_gain("E", CLICK_E)  # +E
			Key.KEY_L: _manual_gain("A", CLICK_A)  # +A

			# Prestige
			Key.KEY_P: _do_prestige_if_possible()

# ---------- ALIASES --------------
# ========= COMPAT : alias pour signaux connectés depuis l’éditeur =========
# Slider température
func _on_temp_slider_value_changed(value: float) -> void:
	_on_TempSlider_value_changed(value)

# Mode d'achat bâtiments
func _on_buy_mode_item_selected(index: int) -> void:
	_on_BuyMode_item_selected(index)

# Boutons Acheter (bâtiments)
func _on_df_buy_pressed() -> void: _on_DFBuy_pressed()
func _on_ce_buy_pressed() -> void: _on_CEBuy_pressed()
func _on_ea_buy_pressed() -> void: _on_EABuy_pressed()
func _on_aa_buy_pressed() -> void: _on_AABuy_pressed()

# Sélecteur de recette (l’éditeur a probablement connecté sur un nom générique)
func _on_option_button_item_selected(index: int) -> void:
	_on_RecipeSelect_item_selected(index)

# Mode d'achat upgrades
func _on_upgrade_mode_item_selected(index: int) -> void:
	_on_UpgradeMode_item_selected(index)

# Boutons Acheter (upgrades)
func _on_uaa_buy_pressed() -> void: _on_UAABuy_pressed()
func _on_up_buy_pressed() -> void: _on_UPBuy_pressed()
func _on_upur_buy_pressed() -> void: _on_UPURBuy_pressed()

# Clics manuels F/E/A
func _on_add_f_btn_pressed() -> void: _on_AddFBtn_pressed()
func _on_add_e_btn_pressed() -> void: _on_AddEBtn_pressed()
func _on_add_a_btn_pressed() -> void: _on_AddABtn_pressed()
# ===========================================================================


# ---------- HANDLERS (connectés depuis l'éditeur) ----------
func _on_DFBuy_pressed() -> void: _buy_building("DF")
func _on_CEBuy_pressed() -> void: _buy_building("CE")
func _on_EABuy_pressed() -> void: _buy_building("EA")
func _on_AABuy_pressed() -> void: _buy_building("AA")

func _on_UAABuy_pressed() -> void: _buy_upgrade("UAA")
func _on_UPBuy_pressed()  -> void: _buy_upgrade("UP")
func _on_UPURBuy_pressed()-> void: _buy_upgrade("UPUR")

func _on_TempSlider_value_changed(value: float) -> void:
	GameController.state.current_temp = value
	temp_value.text = str(int(value))
	_update_recipe_info()

func _on_BuyMode_item_selected(index: int) -> void:
	buy_mode_selected = index
	_refresh_costs()

func _on_UpgradeMode_item_selected(index: int) -> void:
	upgrade_mode_selected = index
	_refresh_upgrades_costs()

func _on_RecipeSelect_item_selected(index: int) -> void:
	match index:
		0: GameController.state.current_recipe = "R1"
		1: GameController.state.current_recipe = "R2"
		2: GameController.state.current_recipe = "R3"
		_: GameController.state.current_recipe = "R1"
	_update_recipe_info()

func _on_AddFBtn_pressed() -> void:
	_manual_gain("F", CLICK_F)

func _on_AddEBtn_pressed() -> void:
	_manual_gain("E", CLICK_E)

func _on_AddABtn_pressed() -> void:
	_manual_gain("A", CLICK_A)
