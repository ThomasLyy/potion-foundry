extends Node

var state = {
	"ecu": 0.0,
	"prod": {"F":0.0,"E":0.0,"A":0.0},
	"stock": {"F":0.0,"E":0.0,"A":0.0},
	"buildings": {"DF":0,"CE":0,"EA":0,"AA":1},
	"upgrades": {},
	"current_recipe": "R1",
	"current_temp": 650.0,
	"last_seen": 0.0,
	"lifetime_ecu": 0.0,
	"seals": 0
}

var _craft_timer: float = 0.0

func _ready():
	pass

func tick(delta):
	# Production linéaire par seconde
	for res in ["F","E","A"]:
		var base: float = 0.0
		var count: int = int(state.buildings.get(res_to_building(res), 0))
		base += count * get_building_base(res)
		base *= pow(1.2, get_upgrade_level("U"+res)) # UF/UE/UA
		state.prod[res] = base
		state.stock[res] += base * delta
	_try_craft(delta)

func res_to_building(res):
	if res == "F": return "DF"
	if res == "E": return "CE"
	if res == "A": return "EA"
	return "DF"

func get_building_base(res):
	match res:
		"F": return 0.1
		"E": return 0.1
		"A": return 0.1
		_: return 0.0

func _t_craft():
	var level = get_upgrade_level("UAA")
	var t = 1.0 * pow(0.9, level)
	return max(t, 0.25)

func _quality_mult(recipe: Dictionary) -> float:
	var t_opt = 0.5 * (recipe.twin[0] + recipe.twin[1])
	var mult_temp = 1.0 - clamp(abs(state.current_temp - t_opt) / 100.0, 0.0, 0.30)
	var purity_tier = min(3, get_upgrade_level("UPUR")) # 0..3
	var mult_purity = 1.0 + 0.05 * purity_tier
	var malus_casse := 0.0
	var tc = _t_craft()
	if tc < 0.33:
		malus_casse = min(0.10, 0.02 * ((0.33 / tc) - 1.0))
	return mult_temp * mult_purity * (1.0 - malus_casse)

func _try_craft(delta):
	var recipe := Data.get_recipe(state.current_recipe)
	if not recipe: return
	_craft_timer += delta
	var tc = _t_craft()
	while _craft_timer >= tc:
		_craft_timer -= tc
		if _can_pay(recipe.cost):
			_pay(recipe.cost)
			var mult_price = pow(1.1, get_upgrade_level("UP"))
			var mult_seals_price = pow(1.08, state.seals)
			var gain = recipe.price * mult_price * mult_seals_price * _quality_mult(recipe)
			state.ecu += gain
			state.lifetime_ecu += gain

func _can_pay(need: Dictionary) -> bool:
	for k in need.keys():
		if state.stock[k] < float(need[k]): return false
	return true

func _pay(need: Dictionary) -> void:
	for k in need.keys():
		state.stock[k] -= float(need[k])

func get_upgrade_level(key: String) -> int:
	if key in state.upgrades: return int(state.upgrades[key])
	return 0

# Prestige
func compute_seals() -> int:
	var base = pow(state.lifetime_ecu / 1e7, 0.6)
	return int(floor(max(base, 0.0)))

func do_prestige():
	state.seals = compute_seals()
	var keep = {"seals": state.seals, "lifetime_ecu": state.lifetime_ecu}
	state = {
		"ecu": 0.0, "prod":{"F":0.0,"E":0.0,"A":0.0},
		"stock":{"F":0.0,"E":0.0,"A":0.0},
		"buildings":{"DF":0,"CE":0,"EA":0,"AA":1},
		"upgrades":{}, "current_recipe":"R1",
		"current_temp":650.0, "last_seen": 0.0,
		"lifetime_ecu": keep.lifetime_ecu, "seals": keep.seals
	}
