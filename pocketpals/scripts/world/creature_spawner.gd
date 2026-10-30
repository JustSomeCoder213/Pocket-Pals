class_name CreatureSpawner
extends Node

## Keeps wild creatures in the outdoor area.
## Each spawn point = {name, habitat, position}. A point may host one creature at a time,
## chosen among species whose habitat matches. A roll against species.spawn_chance
## decides whether the attempt succeeds, so rare species show up less often.
##
## HOW TO ADD A SPAWN POINT: add an entry to SPAWN_POINTS in outdoor_controller.gd.

signal creature_spawned(creature: Node3D)

@export var respawn_min: float = 6.0   ## seconds before a freed point tries again
@export var respawn_max: float = 14.0

var _container: Node3D
var _species: Array[CreatureSpecies] = []
var _points: Array[Dictionary] = []


func setup(container: Node3D, species_list: Array[CreatureSpecies], spawn_points: Array) -> void:
	_container = container
	_species = species_list
	for point in spawn_points:
		_points.append({
			"name": point["name"],
			"habitat": point["habitat"],
			"position": point["position"],
			"creature": null,
			"timer": randf_range(0.2, 1.5),  # first visit: creatures appear within moments
		})


func _process(delta: float) -> void:
	for point in _points:
		if is_instance_valid(point["creature"]):
			continue
		point["timer"] = float(point["timer"]) - delta
		if float(point["timer"]) <= 0.0:
			_try_spawn(point, false)


## Debug helper (F5): fills every empty point immediately, ignoring spawn chance.
func force_spawn_all() -> void:
	for point in _points:
		if not is_instance_valid(point["creature"]):
			_try_spawn(point, true)


func get_creature_count() -> int:
	var count := 0
	for point in _points:
		if is_instance_valid(point["creature"]):
			count += 1
	return count


func _try_spawn(point: Dictionary, forced: bool) -> void:
	var candidates: Array[CreatureSpecies] = []
	for species in _species:
		if species.habitat == point["habitat"]:
			candidates.append(species)
	if candidates.is_empty():
		point["timer"] = 999.0  # nothing lives here; stop checking for a while
		return

	var chosen: CreatureSpecies = candidates.pick_random()
	if not forced and randf() > chosen.spawn_chance:
		point["timer"] = randf_range(respawn_min, respawn_max) * 0.5  # failed roll: retry sooner
		return

	var creature := WildCreature.new()
	creature.name = "Wild_%s" % chosen.species_id
	_container.add_child(creature)  # must be in the tree before setup() uses 'position'
	creature.setup(chosen, point["position"])
	creature.left.connect(_on_creature_left.bind(point))
	point["creature"] = creature
	creature_spawned.emit(creature)


func _on_creature_left(_creature: Node3D, point: Dictionary) -> void:
	point["creature"] = null
	point["timer"] = randf_range(respawn_min, respawn_max)
