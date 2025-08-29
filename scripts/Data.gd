extends Node

var buildings: Array[Dictionary] = []
var upgrades:  Array[Dictionary] = []
var recipes:   Array[Dictionary] = []

func _ready() -> void:
	buildings = _load_json_array("res://data/buildings.json")
	upgrades  = _load_json_array("res://data/upgrades.json")
	recipes   = _load_json_array("res://data/recipes.json")

func _load_json_array(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_warning("Data: file not found " + path)
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Data: cannot open " + path)
		return []
	var parsed_v: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed_v) != TYPE_ARRAY:
		push_warning("Data: invalid JSON (not an array) in " + path)
		return []
	var arr: Array = parsed_v
	var out: Array[Dictionary] = []
	for v in arr:
		if typeof(v) == TYPE_DICTIONARY:
			out.append(v)
	return out

func get_building(id: String) -> Dictionary:
	for b in buildings:
		if String(b.get("id", "")) == id:
			return b
	return {}

func get_upgrade(id: String) -> Dictionary:
	for u in upgrades:
		if String(u.get("id", "")) == id:
			return u
	return {}

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if String(r.get("id", "")) == id:
			return r
	return {}
