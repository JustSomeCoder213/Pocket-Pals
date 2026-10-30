extends Node

## Reads and writes the save file. Registered as an autoload named "SaveManager".
## It knows nothing about creatures or scenes: main.gd gives it a Dictionary to write,
## and receives a validated Dictionary when loading.
##
## Files in user://  (see the Phase 6 notes for the real folder on your computer):
##   save.json          the current save
##   save.bak.json      a copy of the previous good save
##   save.tmp           exists only while a save is being written
##   save_corrupt.json  a damaged save that was set aside (never deleted automatically)

const SAVE_VERSION := 1
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const TEMP_PATH := "user://save.tmp"
const CORRUPT_PATH := "user://save_corrupt.json"
const MAX_ITEM_COUNT := 999
const MAX_COINS := 99999999

## A message for the player after load_game() (empty when everything was normal).
var last_load_note: String = ""
## The reason the last save_game() failed.
var last_error: String = ""


func get_save_folder() -> String:
	return ProjectSettings.globalize_path("user://")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Returns a validated save Dictionary, or {} if there is nothing usable (fresh game).
func load_game() -> Dictionary:
	last_load_note = ""
	var primary := _try_read(SAVE_PATH)
	if primary["status"] == "ok":
		return primary["data"]

	var backup := _try_read(BACKUP_PATH)
	if primary["status"] == "invalid":
		# Keep the damaged file for inspection and clear the way for a new save.
		DirAccess.rename_absolute(SAVE_PATH, CORRUPT_PATH)
		push_warning("SaveManager: save.json was damaged and was moved to save_corrupt.json")
		if backup["status"] == "ok":
			last_load_note = "Your save file was damaged, so your previous backup was loaded."
			return backup["data"]
		last_load_note = "Your save file couldn't be read. It was kept as save_corrupt.json and a new game was started."
		return {}

	# No main save file at all.
	if backup["status"] == "ok":
		last_load_note = "Loaded your backup save."
		return backup["data"]
	return {}


## Writes the save safely. Returns true on success; on failure the old save is untouched.
func save_game(data: Dictionary) -> bool:
	last_error = ""
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(payload, "\t")

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write %s (error %d)." % [TEMP_PATH, FileAccess.get_open_error()])
	file.store_string(text)
	file.close()

	# Read the temp file back. If it isn't valid, the existing save stays as it is.
	if _try_read(TEMP_PATH)["status"] != "ok":
		DirAccess.remove_absolute(TEMP_PATH)
		return _fail("The new save failed verification, so the old save was kept.")

	# Only a valid current save is allowed to become the backup.
	if _try_read(SAVE_PATH)["status"] == "ok":
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if error != OK:
		return _fail("Could not replace the save file (error %d)." % error)
	return true


## Deletes the save and its backup (used by "Reset progress"). save_corrupt.json is kept.
func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# ---------- Internals ----------

func _fail(reason: String) -> bool:
	last_error = reason
	push_error("SaveManager: " + reason)
	return false


## Returns {"status": "missing" | "invalid" | "ok", "data": Dictionary}.
func _try_read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing", "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": "invalid", "data": {}}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"status": "invalid", "data": {}}
	var clean := _sanitize(parsed)
	if clean.is_empty():
		return {"status": "invalid", "data": {}}
	return {"status": "ok", "data": clean}


## Turns untrusted file contents into a Dictionary with every key present and every
## value the right type. Returns {} if the file isn't a save from this game.
func _sanitize(raw: Dictionary) -> Dictionary:
	var version := _as_int(raw.get("version"), 0)
	if version < 1 or version > SAVE_VERSION:
		return {}

	var companion := _as_dict(raw.get("companion"))
	var tutorial := _as_dict(raw.get("tutorial"))
	var creature := _as_dict(raw.get("creature"))
	var inventory := _as_dict(raw.get("inventory"))

	var items := {}
	var raw_items := _as_dict(inventory.get("items"))
	for key in raw_items:
		var count := clampi(_as_int(raw_items[key], 0), 0, MAX_ITEM_COUNT)
		if count > 0:
			items[str(key)] = count

	var decorations := {}
	var raw_decorations := _as_dict(inventory.get("placed_decorations"))
	for slot in raw_decorations:
		decorations[str(slot)] = str(raw_decorations[slot])

	return {
		"version": version,
		"starter_granted": raw.get("starter_granted", false) == true,
		"tutorial": {"step": clampi(_as_int(tutorial.get("step"), 0), 0, 99)},
		"coins": clampi(_as_int(raw.get("coins"), 0), 0, MAX_COINS),
		"companion": {"species_id": str(companion.get("species_id", "mochi"))},
		"creature": {
			"hunger": _as_float(creature.get("hunger"), 70.0),
			"happiness": _as_float(creature.get("happiness"), 70.0),
			"energy": _as_float(creature.get("energy"), 80.0),
			"bond": _as_float(creature.get("bond"), 0.0),
		},
		"inventory": {
			"items": items,
			"equipped_bed": str(inventory.get("equipped_bed", "basic_bed")),
			"equipped_toy": str(inventory.get("equipped_toy", "basic_toy")),
			"placed_decorations": decorations,
		},
		"discovery": _as_dict(raw.get("discovery")),
	}


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## JSON numbers arrive as floats, so both int and float are accepted.
func _as_int(value: Variant, default_value: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return default_value


func _as_float(value: Variant, default_value: float) -> float:
	if value is int:
		return float(value)
	if value is float and is_finite(value):
		return value
	return default_value
