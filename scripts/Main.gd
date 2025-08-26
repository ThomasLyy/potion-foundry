extends Node

# ------ RÉFÉRENCES UI ------
@onready var money_label := $Layout/Header/StocksRow/MoneyLabel
@onready var f_label := $Layout/Header/StocksRow/FLabel
@onready var e_label := $Layout/Header/StocksRow/ELabel
@onready var a_label := $Layout/Header/StocksRow/ALabel

@onready var fprod_label := $Layout/Header/ProdRow/FProdLabel
@onready var eprod_label := $Layout/Header/ProdRow/EProdLabel
@onready var aprod_label := $Layout/Header/ProdRow/AProdLabel

@onready var df_cost := $Layout/BuyPanel/BuyMargin/BuyGrid/DFCost
@onready var ce_cost := $Layout/BuyPanel/BuyMargin/BuyGrid/CECost
@onready var ea_cost := $Layout/BuyPanel/BuyMargin/BuyGrid/EACost
@onready var aa_cost := $Layout/BuyPanel/BuyMargin/BuyGrid/AACost

@onready var temp_slider := $Layout/TempRow/TempSlider
@onready var temp_value := $Layout/TempRow/TempValue

# ------ UTILS ------
func fmt2(x) -> String:
	return str(round(float(x) * 100.0) / 100.0)

func building_cost(id: String, count: int) -> float:
	var b := Data.get_building(id)
	if b.size() == 0:
		return 0.0
	var cost0 := float(b["cost0"])
	var r := float(b["r"])
	return cost0 * pow(r, float(count))

# ------ LIFE CYCLE ------
func _ready():
	# (Option) Amorçage de test initial (tu peux commenter ces lignes quand tu veux tester “à froid”)
	# GameController.state.buildings["DF"] = 1
	GameController.state.current_recipe = "R1"
	GameController.state.current_temp = 650.0
	temp_slider.value = 650.0
	temp_value.text = "650"

	_refresh_all()

func _process(delta):
	GameController.tick(delta)
	_refresh_runtime()

# ------ UI REFRESH ------
func _refresh_runtime():
	# Argent
	money_label.text = str(int(round(GameController.state.ecu))) + " ₠"
	# Stocks
	var s = GameController.state.stock
	f_label.text = "F: " + fmt2(s["F"])
	e_label.text = "E: " + fmt2(s["E"])
	a_label.text = "A: " + fmt2(s["A"])
	# Prod/s
	var p = GameController.state.prod
	fprod_label.text = "F/s: " + fmt2(p["F"])
	eprod_label.text = "E/s: " + fmt2(p["E"])
	aprod_label.text = "A/s: " + fmt2(p["A"])

func _refresh_costs():
	var b = GameController.state.buildings
	df_cost.text = "Coût: " + fmt2(building_cost("DF", int(b["DF"]))) + " ₠"
	ce_cost.text = "Coût: " + fmt2(building_cost("CE", int(b["CE"]))) + " ₠"
	ea_cost.text = "Coût: " + fmt2(building_cost("EA", int(b["EA"]))) + " ₠"
	aa_cost.text = "Coût: " + fmt2(building_cost("AA", int(b["AA"]))) + " ₠"

func _refresh_all():
	_refresh_runtime()
	_refresh_costs()

# ------ ACHATS ------
func _buy_building(id: String):
	var b = GameController.state.buildings
	var n: int = int(b.get(id, 0))
	var cost := building_cost(id, n)
	if GameController.state.ecu >= cost:
		GameController.state.ecu -= cost
		b[id] = n + 1
		_refresh_costs()

# Signaux des boutons (connectés depuis l’onglet Node)
func _on_DFBuy_pressed() -> void:
	_buy_building("DF")

func _on_CEBuy_pressed() -> void:
	_buy_building("CE")

func _on_EABuy_pressed() -> void:
	_buy_building("EA")

func _on_AABuy_pressed() -> void:
	_buy_building("AA")

# ------ TEMP SLIDER ------
# (connecté au signal value_changed du HSlider)
func _on_TempSlider_value_changed(value: float) -> void:
	GameController.state.current_temp = value
	temp_value.text = str(int(value))
