class_name SpeciesDatabase
extends RefCounted

## Static lookup for species definitions, same idea as ItemDatabase:
##   SpeciesDatabase.get_species("mossling")
##   SpeciesDatabase.get_all()          (sorted for the collection screen)
##   SpeciesDatabase.get_wild_species() (everything that doesn't live at Home)
## To add a species: drop a new .tres into res://resources/creatures/.

const SPECIES_DIR := "res://resources/creatures"

static var _species: Dictionary = {}  # species_id (String) -> CreatureSpecies
static var _loaded: bool = false


static func get_species(species_id: String) -> CreatureSpecies:
	_ensure_loaded()
	return _species.get(species_id) as CreatureSpecies


## All species, ordered by collection_order and then by name.
static func get_all() -> Array[CreatureSpecies]:
	_ensure_loaded()
	var result: Array[CreatureSpecies] = []
	for species in _species.values():
		result.append(species)
	result.sort_custom(func(a: CreatureSpecies, b: CreatureSpecies) -> bool:
		if a.collection_order != b.collection_order:
			return a.collection_order < b.collection_order
		return a.display_name < b.display_name
	)
	return result


static func get_wild_species() -> Array[CreatureSpecies]:
	var result: Array[CreatureSpecies] = []
	for species in get_all():
		if species.habitat != "Home":
			result.append(species)
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(SPECIES_DIR)
	if dir == null:
		push_error("SpeciesDatabase: cannot open folder %s" % SPECIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Exported games list resources as "name.tres.remap"; strip that suffix.
			var clean_name := file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var path := "%s/%s" % [SPECIES_DIR, clean_name]
				var species := load(path) as CreatureSpecies
				if species == null or str(species.species_id) == "unknown":
					push_warning("SpeciesDatabase: %s is not a valid CreatureSpecies (missing species_id?)" % path)
				else:
					_species[str(species.species_id)] = species
		file_name = dir.get_next()
	dir.list_dir_end()
