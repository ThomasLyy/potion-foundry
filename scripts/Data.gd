extends Node

var recipes := []
var upgrades := []
var buildings := []
var manifest := {}

func _ready():
	load_all()

func load_all():
	recipes = _load_json("res://data/recipes.json")
	upgrades = _load_json("res://data/upgrades.json")
	buildings = _load_json("res://data/buildings.json")
	manifest = _load_json("res://data/manifest_univers.json")

func _load_json(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		return JSON.parse_string(txt)
	return []

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r.id == id: return r
	return {}

func get_building(id: String) -> Dictionary:
	for b in buildings:
		if b["id"] == id:
			return b
	return {}

func get_upgrade(id: String) -> Dictionary:
	for u in upgrades:
		if u["id"] == id:
			return u
	return {}
