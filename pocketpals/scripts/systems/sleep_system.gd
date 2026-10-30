class_name SleepSystem
extends RefCounted

## Tracks whether the creature is resting and applies recovery each tick.
## Bed effects come from the Sleep items in res://resources/items/.

signal rest_started
signal rest_ended

## Used if the equipped bed ID isn't a known Sleep item (resting on the floor).
const FLOOR_REST := {"name": "Floor", "energy_per_tick": 2.5, "happiness_per_tick": 0.0}

var is_resting: bool = false


func get_bed_data(bed_id: String) -> Dictionary:
	var item := ItemDatabase.get_item(bed_id)
	if item != null and item.category == "Sleep":
		return {
			"name": item.display_name,
			"energy_per_tick": item.energy_per_tick,
			"happiness_per_tick": item.happiness_per_tick,
		}
	return FLOOR_REST


func start_rest() -> void:
	if is_resting:
		return
	is_resting = true
	rest_started.emit()


func stop_rest() -> void:
	if not is_resting:
		return
	is_resting = false
	rest_ended.emit()


## Called by CareSystem once per tick.
func apply_tick(stats: CreatureStats, bed_id: String) -> void:
	if not is_resting:
		return
	var bed: Dictionary = get_bed_data(bed_id)
	stats.add_energy(float(bed["energy_per_tick"]))
	stats.add_happiness(float(bed["happiness_per_tick"]))
	if stats.energy >= stats.max_energy:
		stop_rest()  # fully rested: wake up automatically
