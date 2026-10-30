class_name DiscoverySystem
extends RefCounted

## Tracks the collection. register_photo() is the ONLY place that decides whether a
## photo is a new discovery, so the bonus can never be paid twice.
##
## to_dict() / from_dict() are ready for the save system (Phase 6). Species IDs are
## stored as plain Strings, never as node references.

signal changed
signal species_discovered(species_id: String)

var _records: Dictionary = {}  # species_id (String) -> {"best_score": int, "photos": int}
var _starter_id: String = ""


## The starter counts as discovered from the beginning (it is a gift, not a find).
func setup(starter: CreatureSpecies) -> void:
	_starter_id = str(starter.species_id)
	_records[_starter_id] = _empty_record()
	changed.emit()


func is_discovered(species_id: String) -> bool:
	return _records.has(species_id)


func get_record(species_id: String) -> Dictionary:
	return _records.get(species_id, _empty_record())


func get_discovered_count() -> int:
	var count := 0
	for species in SpeciesDatabase.get_all():
		if is_discovered(str(species.species_id)):
			count += 1
	return count


func get_total_count() -> int:
	return SpeciesDatabase.get_all().size()


## Takes a VALID photo result from PhotoCamera and returns an updated copy with:
##   is_new_discovery (bool), discovery_bonus (int), and coins increased by the bonus.
func register_photo(result: Dictionary) -> Dictionary:
	var species_id := str(result["species_id"])
	var is_new := not _records.has(species_id)
	var record: Dictionary = _records.get(species_id, _empty_record())
	record["photos"] = int(record["photos"]) + 1
	record["best_score"] = maxi(int(record["best_score"]), int(result["score"]))
	_records[species_id] = record

	var updated := result.duplicate()
	updated["is_new_discovery"] = is_new
	updated["discovery_bonus"] = 0
	if is_new:
		var species := SpeciesDatabase.get_species(species_id)
		var bonus := species.discovery_bonus if species != null else 0
		updated["discovery_bonus"] = bonus
		updated["coins"] = int(result["coins"]) + bonus
		species_discovered.emit(species_id)
	changed.emit()
	return updated


## Forgets everything except the starter (debug key F6, and Phase 6 "reset progress").
func reset() -> void:
	_records.clear()
	if _starter_id != "":
		_records[_starter_id] = _empty_record()
	changed.emit()


func to_dict() -> Dictionary:
	return {"records": _records.duplicate(true)}


## Returns false (and changes nothing) if the data is malformed.
func from_dict(data: Dictionary) -> bool:
	var raw: Variant = data.get("records")
	if not (raw is Dictionary):
		return false
	var loaded: Dictionary = {}
	for key in raw:
		var entry: Variant = raw[key]
		if not (entry is Dictionary):
			return false
		loaded[str(key)] = {
			"best_score": int(entry.get("best_score", 0)),
			"photos": int(entry.get("photos", 0)),
		}
	if _starter_id != "" and not loaded.has(_starter_id):
		loaded[_starter_id] = _empty_record()
	_records = loaded
	changed.emit()
	return true


func _empty_record() -> Dictionary:
	return {"best_score": 0, "photos": 0}
