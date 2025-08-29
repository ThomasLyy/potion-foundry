extends Node

var save_path := "user://save.json"

func save(state: Dictionary) -> void:
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))

func load_state() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f = FileAccess.open(save_path, FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		var data = JSON.parse_string(txt)
		if typeof(data) == TYPE_DICTIONARY:
			return data
	return {}
