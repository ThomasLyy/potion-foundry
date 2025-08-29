extends Node
# ========================================================================
#  Main.gd
#  - UI & gameplay de surface
#  - Économie affichée & transigée en ENTIER
#  - Auto-craft désactivé tant que UAA == 0 (GameController.gd)
#  - Onboarding léger (3 tips)
# ========================================================================

# === SECTION: RÉFÉRENCES UI ==============================================
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

# Manuel & Craft 1x
@onready var addf_btn: Button = $Layout/ManualRow/AddFBtn
@onready var adde_btn: Button = $Layout/ManualRow/AddEBtn
@onready var adda_btn: Button = $Layout/ManualRow/AddABtn
@onready var craft_once_btn: Button = $Layout/CraftRow/CraftOnceBtn

# Achats Bâtiments
@onready var df_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFName
@onready var ce_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CEName
@onready var ea_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EAName
@onready var aa_name: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AAName
@onready var df_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFCost
@onready var ce_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CECost
@onready var ea_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EACost
@onready var aa_cost: Label = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AACost
@onready var df_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/DFBuy
@onready var ce_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/CEBuy
@onready var ea_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/EABuy
@onready var aa_buy: Button = $Layout/BuyPanel/BuyMargin/BuyBody/BuyGrid/AABuy

# Upgrades
@onready var uaa_name: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAAName
@onready var uaa_cost: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAACost
@onready var up_name:  Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPName
@onready var up_cost:  Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPCost
@onready var upur_name: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURName
@onready var upur_cost: Label = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURCost
@onready var uaa_buy: Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UAABuy
@onready var up_buy:  Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPBuy
@onready var upur_buy: Button = $Layout/UpgradesPanel/UpMargin/UpBody/UpGrid/UPURBuy
@onready var upgrades_panel: PanelContainer = $Layout/UpgradesPanel

# --- Settings / dialogs ---
@onready var settings_btn: Button = %SettingsBtn
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var export_btn: Button = %ExportBtn
@onready var import_btn: Button = %ImportBtn
@onready var reset_run_btn: Button = %ResetRunBtn
@onready var reset_all_btn: Button = %ResetAllBtn
@onready var export_dialog: FileDialog = %ExportDialog
@onready var import_dialog: FileDialog = %ImportDialog
@onready var confirm_reset_run: ConfirmationDialog = %ConfirmResetRun
@onready var confirm_reset_all: ConfirmationDialog = %ConfirmResetAll

# OptionButtons (trouvés de façon robuste au _ready)
var buy_mode_btn: OptionButton = null
var recipe_select_btn: OptionButton = null
var upgrade_mode_btn: OptionButton = null

# === SECTION: RECIPES SELECT (liste dynamique affichée) ==================
var _recipe_ids_displayed: Array[String] = []

# === SECTION: PERF & AUTOSAVE ============================================
const SIM_DT: float = 0.10
const UI_DT:  float = 0.10
const AUTOSAVE_EVERY: float = 60.0
const CLICK_F: int = 1
const CLICK_E: int = 1
const CLICK_A: int = 1

var _sim_accum: float = 0.0
var _ui_accum: float = 0.0
var _autosave_accum: float = 0.0
var _did_save_on_exit: bool = false

var buy_mode_selected: int = 0
var upgrade_mode_selected: int = 0

# === SECTION: UTILS (entiers & format) ===================================
func i_round(x: float) -> int: return int(round(x))
func i_ceil(x: float) -> int: return int(ceil(x))
func fmt0(x) -> String: return str(int(round(float(x))))

func fmt2(x) -> String: # (garde si besoin ponctuel)
	return str(round(float(x) * 100.0) / 100.0)

func _ensure_stock_dict():
	if GameController.state.stock == null:
		GameController.state.stock = {}
	for k in ["F","E","A"]:
		if not GameController.state.stock.has(k):
			GameController.state.stock[k] = 0.0

func _upgrade_level(key: String) -> int:
	var u: Dictionary = GameController.state.upgrades
	return int(u.get(key, 0))

func _craft_time() -> float:
	var level: int = _upgrade_level("UAA")
	return max(1.0 * pow(0.9, float(level)), 0.25)
	
func _new_default_state() -> Dictionary:
	return {
		"ecu": 0.0,
		"stock": {"F": 0.0, "E": 0.0, "A": 0.0},
		"buildings": {},
		"upgrades": {},
		"current_recipe": "R1",
		"current_temp": 650.0,
		"seals": 0,
		"lifetime_ecu": 0.0
	}

func _validate_state(d: Variant) -> bool:
	return typeof(d) == TYPE_DICTIONARY \
		and d.has("ecu") and d.has("stock") and d.has("buildings") and d.has("upgrades") \
		and d.has("current_recipe") and d.has("current_temp") \
		and d.has("seals") and d.has("lifetime_ecu")

func _export_to_path(path: String) -> bool:
	var txt := JSON.stringify(GameController.state)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[Export] Impossible d’ouvrir: " + path)
		return false
	f.store_string(txt)
	f.flush()
	print("[Export] OK → ", path)
	return true

func _import_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("[Import] Fichier introuvable: " + path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[Import] Ouverture impossible: " + path)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not _validate_state(parsed):
		push_error("[Import] JSON invalide (structure inattendue).")
		return false
	GameController.state = parsed
	_ensure_stock_dict()     # si tu as déjà cette fonction, garde l’appel
	_refresh_all()
	_do_save(false)
	print("[Import] OK ← ", path)
	return true

	
# === SECTION: RECIPES UNLOCK HELPERS =====================================
func _ensure_recipe_unlock_state():
	if not GameController.state.has("recipes_unlocked"):
		GameController.state.recipes_unlocked = {"R1": true, "R2": false, "R3": false}

func _rebuild_recipe_select():
	if recipe_select_btn == null:
		return
	_recipe_ids_displayed.clear()
	recipe_select_btn.clear()

	var unlocks: Dictionary = GameController.state.recipes_unlocked
	var ids: Array[String] = ["R1", "R2", "R3"]  # <— typé pour que 'rid' soit String

	for rid: String in ids:
		if bool(unlocks.get(rid, false)):
			var r: Dictionary = Data.get_recipe(rid)
			var label: String = rid  # <— typé
			if not r.is_empty():
				label = "%s — %s" % [rid, str(r.get("name", rid))]
			recipe_select_btn.add_item(label)
			_recipe_ids_displayed.append(rid)

	var want: String = str(GameController.state.current_recipe)
	var idx: int = _recipe_ids_displayed.find(want)
	if idx == -1:
		if _recipe_ids_displayed.size() > 0:
			GameController.state.current_recipe = _recipe_ids_displayed[0]
			idx = 0
		else:
			return
	recipe_select_btn.select(idx)

func _apply_recipe_unlocks():
	_ensure_recipe_unlock_state()
	var changed: bool = false
	var L: int = i_round(GameController.state.lifetime_ecu)
	var b: Dictionary = GameController.state.buildings

	# Règles simples (ajuste si tu veux) :
	# - R2 dès 15 ₠ lifetime
	# - R3 dès 60 ₠ lifetime OU dès qu'on possède ≥1 CE
	if L >= 15 and not bool(GameController.state.recipes_unlocked.get("R2", false)):
		GameController.state.recipes_unlocked["R2"] = true
		_show_tip("Nouvelle recette débloquée : R2")
		changed = true

	if (L >= 60 or int(b.get("CE", 0)) >= 1) and not bool(GameController.state.recipes_unlocked.get("R3", false)):
		GameController.state.recipes_unlocked["R3"] = true
		_show_tip("Nouvelle recette débloquée : R3")
		changed = true

	if changed:
		_rebuild_recipe_select()
		_update_recipe_info()

# === SECTION: COÛTS & QUANTITÉS (géométrique) ============================
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

# === SECTION: WRAPPERS ENTIER (affichage & paiement) =====================
func building_bulk_cost_int(id: String, start_count: int, k: int) -> int:
	return i_ceil(building_bulk_cost(id, start_count, k))

func upgrade_bulk_cost_int(id: String, start_level: int, k: int) -> int:
	return i_ceil(upgrade_bulk_cost(id, start_level, k))

func _can_pay(total: int) -> bool:
	return i_round(GameController.state.ecu) >= total

# === SECTION: QUANTITÉS COURANTES (×1/×10/×Max) ==========================
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

func max_affordable_qty_upgrade(id: String, start_level: int, budget: float) -> int:
	var u: Dictionary = Data.get_upgrade(id)
	if u.is_empty() or budget <= 0.0: return 0
	var max_level: int = int(u.get("max", 999999))
	var remaining: int = max(0, max_level - start_level)
	if remaining <= 0: return 0
	var cost0: float = float(u["cost0"])
	var r: float = float(u["r"])
	if abs(r - 1.0) < 0.000001: return min(int(floor(budget / cost0)), remaining)
	var denom: float = cost0 * pow(r, float(start_level))
	var inside: float = 1.0 + (r - 1.0) * (budget / max(denom, 0.000001))
	if inside <= 1.000001: return 0
	return min(int(floor(log(inside) / log(r))), remaining)

func current_buy_qty(id: String) -> int:
	var b: Dictionary = GameController.state.buildings
	var n: int = int(b.get(id, 0))
	var sel: int = buy_mode_selected
	if buy_mode_btn: sel = buy_mode_btn.selected
	match sel:
		0: return 1
		1: return 10
		2: return max_affordable_qty(id, n, float(GameController.state.ecu))
		_: return 1

func current_upgrade_qty(id: String) -> int:
	var lvl: int = _upgrade_level(id)
	var sel: int = upgrade_mode_selected
	if upgrade_mode_btn: sel = upgrade_mode_btn.selected
	match sel:
		0: return 1
		1: return 10
		2: return max_affordable_qty_upgrade(id, lvl, float(GameController.state.ecu))
		_: return 1

# === SECTION: ESTIMÉ PRIX / CRAFT (pour l’UI) ============================
func _price_estimate(recipe: Dictionary) -> float:
	if recipe.is_empty(): return 0.0
	var base_price: float = float(recipe["price"])
	var t_opt: float = 0.5 * (float(recipe["twin"][0]) + float(recipe["twin"][1]))
	var mult_temp: float = 1.0 - clamp(abs(GameController.state.current_temp - t_opt) / 100.0, 0.0, 0.30)
	var purity_tier: int = min(3, _upgrade_level("UPUR"))
	var mult_purity: float = 1.0 + 0.05 * float(purity_tier)
	var malus: float = 0.0
	var tc: float = _craft_time()
	if tc < 0.33:
		malus = min(0.10, 0.02 * ((0.33 / tc) - 1.0))
	var mult_price: float = pow(1.1, float(_upgrade_level("UP")))
	var mult_seals: float = pow(1.08, float(GameController.state.seals))
	return base_price * mult_temp * mult_purity * (1.0 - malus) * mult_price * mult_seals

# === SECTION: SAVE/LOAD (sans offline) ===================================
func _do_save(show_log: bool = false) -> void:
	SaveManager.save(GameController.state)
	if show_log: print("Sauvegardé.")

func _do_load_or_init() -> void:
	var loaded: Dictionary = SaveManager.load_state()
	if loaded.is_empty():
		GameController.state.current_recipe = "R1"
		GameController.state.current_temp = 650.0
	else:
		GameController.state = loaded

	_ensure_stock_dict()
	_ensure_recipe_unlock_state()
	_ensure_onboarding_state()
	_ensure_achievements_state()


	if temp_slider: temp_slider.value = float(GameController.state.current_temp)
	if temp_value:  temp_value.text = str(int(GameController.state.current_temp))

	_rebuild_recipe_select()
	_apply_unlocks()
	_refresh_all()

	_maybe_trigger_onboarding()
	_check_achievements()


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

# === SECTION: READY (trouver OptionButtons + data initiale) ==============
func _ready():
	# OptionButtons résolus de manière robuste (garde si structure bouge)
	buy_mode_btn = _find_option_button([
		"Layout/BuyPanel/BuyMargin/BuyBody/BuyToolbar/BuyMode",
		"BuyPanel/BuyMargin/BuyBody/BuyToolbar/BuyMode"
	])
	if buy_mode_btn:
		buy_mode_btn.select(0)
		if not buy_mode_btn.is_connected("item_selected", Callable(self, "_on_BuyMode_item_selected")):
			buy_mode_btn.connect("item_selected", Callable(self, "_on_BuyMode_item_selected"))

	recipe_select_btn = _find_option_button([
		"Layout/RecipeRow/RecipeSelect",
		"RecipeRow/RecipeSelect"
	])
	if recipe_select_btn:
		if not recipe_select_btn.is_connected("item_selected", Callable(self, "_on_RecipeSelect_item_selected")):
			recipe_select_btn.connect("item_selected", Callable(self, "_on_RecipeSelect_item_selected"))

	upgrade_mode_btn = _find_option_button([
		"Layout/UpgradesPanel/UpMargin/UpBody/UpToolbar/UpgradeMode",
		"UpgradesPanel/UpMargin/UpBody/UpToolbar/UpgradeMode"
	])
	if upgrade_mode_btn:
		upgrade_mode_btn.select(0)
		if not upgrade_mode_btn.is_connected("item_selected", Callable(self, "_on_UpgradeMode_item_selected")):
			upgrade_mode_btn.connect("item_selected", Callable(self, "_on_UpgradeMode_item_selected"))

	_do_load_or_init()

func _find_option_button(candidates: Array[String]) -> OptionButton:
	for p in candidates:
		var n: Node = get_node_or_null(p)
		if n != null: return n as OptionButton
	return null

# === SECTION: PROCESS (boucle économe) ===================================
func _process(delta):
	_sim_accum += delta
	while _sim_accum >= SIM_DT:
		GameController.tick(SIM_DT)
		_sim_accum -= SIM_DT

	if temp_slider:
		var v: float = float(temp_slider.value)
		if v != GameController.state.current_temp:
			GameController.state.current_temp = v
			if temp_value: temp_value.text = str(int(v))
			_update_recipe_info()

	_ui_accum += delta
	if _ui_accum >= UI_DT:
		_ui_accum = 0.0
		_refresh_runtime()
		_refresh_costs()
		_refresh_upgrades_costs()

	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_EVERY:
		_autosave_accum = 0.0
		_do_save(false)

# === SECTION: INPUT (raccourcis clavier) =================================
func _select_buy_mode(i: int) -> void:
	buy_mode_selected = clamp(i, 0, 2)
	if buy_mode_btn: buy_mode_btn.select(buy_mode_selected)
	_refresh_costs()

func _select_upgrade_mode(i: int) -> void:
	upgrade_mode_selected = clamp(i, 0, 2)
	if upgrade_mode_btn: upgrade_mode_btn.select(upgrade_mode_selected)
	_refresh_upgrades_costs()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			Key.KEY_1: _select_buy_mode(0)
			Key.KEY_2: _select_buy_mode(1)
			Key.KEY_3: _select_buy_mode(2)
			Key.KEY_4: _select_upgrade_mode(0)
			Key.KEY_5: _select_upgrade_mode(1)
			Key.KEY_6: _select_upgrade_mode(2)
			Key.KEY_Q: _buy_building("DF")
			Key.KEY_W: _buy_building("CE")
			Key.KEY_E: _buy_building("EA")
			Key.KEY_R: _buy_building("AA")
			Key.KEY_A: _buy_upgrade("UAA")
			Key.KEY_S: _buy_upgrade("UP")
			Key.KEY_D: _buy_upgrade("UPUR")
			Key.KEY_J: _manual_gain("F", CLICK_F)
			Key.KEY_K: _manual_gain("E", CLICK_E)
			Key.KEY_L: _manual_gain("A", CLICK_A)
			Key.KEY_C: _craft_once_if_possible()

# === SECTION: REFRESH UI ==================================================
func _refresh_runtime():
	money_label.text = fmt0(GameController.state.ecu) + " ₠"
	var s = GameController.state.stock
	f_label.text = "F: " + fmt0(s["F"])
	e_label.text = "E: " + fmt0(s["E"])
	a_label.text = "A: " + fmt0(s["A"])

	var p = GameController.state.prod
	fprod_label.text = "F/s: " + fmt0(p["F"])
	eprod_label.text = "E/s: " + fmt0(p["E"])
	aprod_label.text = "A/s: " + fmt0(p["A"])

	var b: Dictionary = GameController.state.buildings
	df_name.text = "Distillateur de Feu (DF) — x" + str(int(b.get("DF", 0)))
	ce_name.text = "Condenseur d’Eau (CE) — x"   + str(int(b.get("CE", 0)))
	ea_name.text = "Éoliseur d’Air (EA) — x"     + str(int(b.get("EA", 0)))
	aa_name.text = "Atelier d’Alchimie (AA) — x" + str(int(b.get("AA", 0)))

	_update_recipe_info()
	_refresh_upgrades_runtime()
	_apply_unlocks()
	_apply_recipe_unlocks()
	_maybe_trigger_onboarding()
	_check_achievements()

func _update_recipe_info():
	var rid: String = str(GameController.state.current_recipe)
	var r: Dictionary = Data.get_recipe(rid)
	if r.is_empty():
		recipe_info.text = ""
		return
	var costs: Array[String] = []
	for k in r["cost"].keys():
		costs.append("%s:%s" % [str(k), fmt0(r["cost"][k])])
	var cost_str: String = "Coût " + ", ".join(costs)
	var price_i: int = i_round(float(r["price"]))
	var est_i:   int = i_round(_price_estimate(r))
	recipe_info.text = "%s | Prix base: %s ₠ | Estimé/craft: %s ₠" % [cost_str, fmt0(price_i), fmt0(est_i)]

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

	var t_df: int = building_bulk_cost_int("DF", n_df, qdf)
	var t_ce: int = building_bulk_cost_int("CE", n_ce, qce)
	var t_ea: int = building_bulk_cost_int("EA", n_ea, qea)
	var t_aa: int = building_bulk_cost_int("AA", n_aa, qaa)

	df_cost.text = "Coût: %s ₠ (×%d)" % [fmt0(t_df), qdf]
	ce_cost.text = "Coût: %s ₠ (×%d)" % [fmt0(t_ce), qce]
	ea_cost.text = "Coût: %s ₠ (×%d)" % [fmt0(t_ea), qea]
	aa_cost.text = "Coût: %s ₠ (×%d)" % [fmt0(t_aa), qaa]

	if df_buy:
		df_buy.disabled = not _can_pay(t_df) or qdf <= 0
		df_buy.tooltip_text = "Prochaine unité: " + fmt0(i_ceil(building_cost("DF", n_df))) + " ₠"
	if ce_buy:
		ce_buy.disabled = not _can_pay(t_ce) or qce <= 0
		ce_buy.tooltip_text = "Prochaine unité: " + fmt0(i_ceil(building_cost("CE", n_ce))) + " ₠"
	if ea_buy:
		ea_buy.disabled = not _can_pay(t_ea) or qea <= 0
		ea_buy.tooltip_text = "Prochaine unité: " + fmt0(i_ceil(building_cost("EA", n_ea))) + " ₠"
	if aa_buy:
		aa_buy.disabled = not _can_pay(t_aa) or qaa <= 0
		aa_buy.tooltip_text = "Prochaine unité: " + fmt0(i_ceil(building_cost("AA", n_aa))) + " ₠"

func _refresh_upgrades_runtime():
	var lvl_uaa: int = _upgrade_level("UAA")
	var status := "OFF" if lvl_uaa == 0 else "ON"
	uaa_name.text = "Vitesse Atelier (UAA) — L" + str(lvl_uaa) + " (" + status + ")"

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

	var t_uaa: int = upgrade_bulk_cost_int("UAA", l_uaa, q_uaa)
	var t_up:  int = upgrade_bulk_cost_int("UP",  l_up,  q_up)
	var t_pur: int = upgrade_bulk_cost_int("UPUR",l_pur, q_pur)

	uaa_cost.text = "Coût: %s ₠ (×%d)" % [fmt0(t_uaa), q_uaa]
	up_cost.text  = "Coût: %s ₠ (×%d)" % [fmt0(t_up),  q_up]
	upur_cost.text= "Coût: %s ₠ (×%d)" % [fmt0(t_pur), q_pur]

	var max_pur: int = int(Data.get_upgrade("UPUR").get("max", 3))
	if uaa_buy:
		uaa_buy.disabled = not _can_pay(t_uaa) or q_uaa <= 0
		uaa_buy.tooltip_text = ""
	if up_buy:
		up_buy.disabled  = not _can_pay(t_up)  or q_up  <= 0
		up_buy.tooltip_text = ""
	if upur_buy:
		var capped: bool = (l_pur >= max_pur)
		upur_buy.disabled = capped or not _can_pay(t_pur) or q_pur <= 0
		upur_buy.tooltip_text = "Niveau max atteint (%d)" % max_pur if capped else ""

func _refresh_all():
	_refresh_runtime()
	_refresh_costs()
	_refresh_upgrades_runtime()
	_refresh_upgrades_costs()

# === SECTION: UNLOCKS (déblocage progressif) =============================
func _apply_unlocks():
	var unlocked_ce: bool = float(GameController.state.lifetime_ecu) > 0.0
	var unlocked_ea: bool = float(GameController.state.lifetime_ecu) >= 50.0 or int(GameController.state.buildings.get("CE", 0)) > 0
	var unlocked_up: bool = float(GameController.state.lifetime_ecu) >= 10.0

	ce_name.visible = unlocked_ce
	ce_cost.visible = unlocked_ce
	ce_buy.visible  = unlocked_ce

	ea_name.visible = unlocked_ea
	ea_cost.visible = unlocked_ea
	ea_buy.visible  = unlocked_ea

	if upgrades_panel:
		upgrades_panel.visible = unlocked_up

# === SECTION: LOGIQUE D'ACHAT ============================================
func _buy_building(id: String):
	var b: Dictionary = GameController.state.buildings
	var n: int = int(b.get(id, 0))
	var q: int = current_buy_qty(id)
	if q <= 0: return
	var total: int = building_bulk_cost_int(id, n, q)
	if _can_pay(total):
		GameController.state.ecu = float(i_round(GameController.state.ecu) - total)
		b[id] = n + q
		_refresh_costs()
		_check_achievements()


func _buy_upgrade(id: String):
	var lvl: int = _upgrade_level(id)
	var q: int = current_upgrade_qty(id)
	if q <= 0: return
	var total: int = upgrade_bulk_cost_int(id, lvl, q)
	if _can_pay(total):
		GameController.state.ecu = float(i_round(GameController.state.ecu) - total)
		GameController.state.upgrades[id] = lvl + q
		_refresh_upgrades_runtime()
		_refresh_upgrades_costs()
		_update_recipe_info()
		_check_achievements()


# === SECTION: CLICS MANUELS & CRAFT 1x ===================================
func _manual_gain(res: String, base_amount: int) -> void:
	_ensure_stock_dict()
	var mult: float = pow(1.2, float(_upgrade_level("U" + res)))
	var current: int = i_round(float(GameController.state.stock.get(res, 0.0)))
	var delta: int = i_round(float(base_amount) * mult)
	GameController.state.stock[res] = float(current + delta)
	_refresh_runtime()

func _can_craft_recipe(r: Dictionary) -> bool:
	for k in r["cost"].keys():
		var need := i_round(float(r["cost"][k]))
		if int(floor(float(GameController.state.stock.get(k, 0.0)))) < need:
			return false
	return true

func _consume_recipe_costs(r: Dictionary, times: int) -> void:
	for k in r["cost"].keys():
		var need := i_round(float(r["cost"][k])) * times
		var cur := i_round(float(GameController.state.stock.get(k, 0.0)))
		GameController.state.stock[k] = float(cur - need)

func _craft_once_if_possible() -> void:
	_ensure_stock_dict()
	var rid: String = str(GameController.state.current_recipe)
	var r: Dictionary = Data.get_recipe(rid)
	if r.is_empty(): return
	if not _can_craft_recipe(r): return

	_consume_recipe_costs(r, 1)
	var gain: int = i_round(_price_estimate(r))
	GameController.state.ecu = float(i_round(GameController.state.ecu) + gain)
	GameController.state.lifetime_ecu = float(i_round(GameController.state.lifetime_ecu) + gain)
	_refresh_runtime()
	_refresh_costs()
	_refresh_upgrades_costs()
	_apply_unlocks()
	_check_achievements()


# === SECTION: HANDLERS (signaux) =========================================
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
	if index < 0 or index >= _recipe_ids_displayed.size():
		return
	GameController.state.current_recipe = _recipe_ids_displayed[index]
	_update_recipe_info()

func _on_DFBuy_pressed() -> void: _buy_building("DF")
func _on_CEBuy_pressed() -> void: _buy_building("CE")
func _on_EABuy_pressed() -> void: _buy_building("EA")
func _on_AABuy_pressed() -> void: _buy_building("AA")

func _on_UAABuy_pressed() -> void: _buy_upgrade("UAA")
func _on_UPBuy_pressed()  -> void: _buy_upgrade("UP")
func _on_UPURBuy_pressed()-> void: _buy_upgrade("UPUR")

func _on_AddFBtn_pressed() -> void: _manual_gain("F", CLICK_F)
func _on_AddEBtn_pressed() -> void: _manual_gain("E", CLICK_E)
func _on_AddABtn_pressed() -> void: _manual_gain("A", CLICK_A)

func _on_CraftOnceBtn_pressed() -> void: _craft_once_if_possible()

# --- Settings button ---
func _on_SettingsBtn_pressed() -> void:
	if settings_popup:
		settings_popup.popup_centered()

# --- Settings popup actions ---
func _on_ExportBtn_pressed() -> void:
	if export_dialog:
		if export_dialog.current_file.is_empty():
			export_dialog.current_file = "potion_foundry_save.json"
		export_dialog.popup_centered_ratio(0.7)

func _on_ImportBtn_pressed() -> void:
	if import_dialog:
		import_dialog.popup_centered_ratio(0.7)

func _on_ResetRunBtn_pressed() -> void:
	if confirm_reset_run:
		confirm_reset_run.dialog_text = "Réinitialiser le run ?\n(Sceaux & lifetime sont conservés.)"
		confirm_reset_run.popup_centered()

func _on_ResetAllBtn_pressed() -> void:
	if confirm_reset_all:
		confirm_reset_all.dialog_text = "Réinitialisation complète ?\n(Tout sera perdu, y compris Sceaux et lifetime.)"
		confirm_reset_all.popup_centered()

# --- Dialog results ---
func _on_ExportDialog_file_selected(path: String) -> void:
	_export_to_path(path)

func _on_ImportDialog_file_selected(path: String) -> void:
	_import_from_path(path)

func _on_ConfirmResetRun_confirmed() -> void:
	# garde Sceaux & lifetime
	var keep_seals: int = int(GameController.state.seals)
	var keep_life: float = float(GameController.state.lifetime_ecu)
	var keep_recipe: String = str(GameController.state.current_recipe)
	var keep_temp: float = float(GameController.state.current_temp)

	GameController.state.ecu = 0.0
	GameController.state.stock = {"F": 0.0, "E": 0.0, "A": 0.0}
	GameController.state.buildings = {}
	GameController.state.upgrades = {}
	GameController.state.seals = keep_seals
	GameController.state.lifetime_ecu = keep_life
	GameController.state.current_recipe = keep_recipe
	GameController.state.current_temp = keep_temp

	_refresh_all()
	_do_save(false)
	print("[ResetRun] OK (seals=", keep_seals, ", lifetime=", fmt2(keep_life), ")")

func _on_ConfirmResetAll_confirmed() -> void:
	GameController.state = _new_default_state()
	_refresh_all()
	_do_save(false)
	print("[ResetAll] OK (tout remis à zéro)")


# === SECTION EXT: ONBOARDING =============================================
var _tip_queue: Array[String] = []
var _tip_dialog: AcceptDialog = null
var _tip_showing: bool = false

func _ensure_onboarding_state():
	if not GameController.state.has("onb_step"):
		GameController.state["onb_step"] = 0

func _show_tip(msg: String) -> void:
	_tip_queue.append(msg)
	if not _tip_showing:
		_dequeue_tip()
		
func _dequeue_tip() -> void:
	if _tip_queue.is_empty():
		_tip_showing = false
		return
	_tip_showing = true

	if _tip_dialog == null:
		_tip_dialog = AcceptDialog.new()
		_tip_dialog.title = "Conseil"
		add_child(_tip_dialog)
		# Connecter une seule fois les fermetures possibles
		if not _tip_dialog.is_connected("confirmed", Callable(self, "_on_tip_closed")):
			_tip_dialog.connect("confirmed", Callable(self, "_on_tip_closed"))
		if not _tip_dialog.is_connected("canceled", Callable(self, "_on_tip_closed")):
			_tip_dialog.connect("canceled", Callable(self, "_on_tip_closed"))
		if not _tip_dialog.is_connected("close_requested", Callable(self, "_on_tip_closed")):
			_tip_dialog.connect("close_requested", Callable(self, "_on_tip_closed"))

	_tip_dialog.dialog_text = _tip_queue.pop_front()
	_tip_dialog.popup_centered()  # une seule fenêtre exclusive à la fois


func _on_tip_closed() -> void:
	_dequeue_tip()  # affiche le tip suivant s'il y en a


func _maybe_trigger_onboarding():
	_ensure_onboarding_state()
	var step: int = int(GameController.state.get("onb_step", 0))

	if step == 0:
		_show_tip("Bienvenue ! Cliquez sur +F (ou J) pour générer votre première essence.")
		GameController.state["onb_step"] = 1
		return

	if step == 1 and float(GameController.state.stock.get("F", 0.0)) >= 1.0:
		_show_tip("Parfait ! Achetez 1 Distillateur de Feu (bouton DF ou Q) pour automatiser la production.")
		GameController.state["onb_step"] = 2
		return

	if step == 2 and int(GameController.state.buildings.get("DF", 0)) >= 1:
		_show_tip("Bien ! Réglez la température et brassez 1x (bouton ou C). L’auto-brassage s’active au niveau 1 de UAA.")
		GameController.state["onb_step"] = 3
		return

	if step == 3 and i_round(GameController.state.lifetime_ecu) >= 10:
		_show_tip("Top ! Les Améliorations sont débloquées — continuez à acheter et améliorer.")
		GameController.state["onb_step"] = 4
		return
		
func _ensure_achievements_state():
	if not GameController.state.has("achievements"):
		GameController.state["achievements"] = {}

func _unlock_ach(key: String, title: String) -> void:
	var a: Dictionary = GameController.state.achievements
	if not bool(a.get(key, false)):
		a[key] = true
		_show_tip("Succès : " + title)
		
func _check_achievements() -> void:
	_ensure_achievements_state()
	var s := GameController.state
	var _a: Dictionary = s.achievements

	# 1) Bâtiments
	if int(s.buildings.get("DF", 0)) >= 1:
		_unlock_ach("first_df", _ACH_KEYS["first_df"])
	if int(s.buildings.get("DF", 0)) >= 10:
		_unlock_ach("df10", _ACH_KEYS["df10"])

	# 2) Upgrades
	if int(s.upgrades.get("UAA", 0)) >= 1:
		_unlock_ach("auto_on", _ACH_KEYS["auto_on"])

	# 3) Recettes débloquées
	if bool(s.recipes_unlocked.get("R2", false)):
		_unlock_ach("r2", _ACH_KEYS["r2"])
	if bool(s.recipes_unlocked.get("R3", false)):
		_unlock_ach("r3", _ACH_KEYS["r3"])

	# 4) Économie globale
	if i_round(s.lifetime_ecu) >= 100:
		_unlock_ach("ecu100", _ACH_KEYS["ecu100"])


# === SECTION EXT: ACHIEVEMENTS ===========================================
# Définition minimale des jalons. On détecte ces conditions à chaque refresh.
const _ACH_KEYS := {
	"first_df": "Distillateur : premier acheté !",
	"df10":     "10 Distillateurs — cap franchi",
	"auto_on":  "Atelier automatique activé (UAA ≥ 1)",
	"r2":       "Recette R2 débloquée",
	"r3":       "Recette R3 débloquée",
	"ecu100":   "100 écus brassés au total"
}

# === SECTION EXT: FUTURS AJOUTS ==========================================
# - Succès / Jalons
# - Recettes supplémentaires et déblocages
# - Export/Import sauvegarde
