class_name CreatureStats
extends RefCounted

## The numbers that describe how the creature feels. No game rules live here;
## CareSystem decides how they change. Anything that displays stats (the HUD)
## listens to the "changed" signal.

signal changed
signal bond_level_changed(new_level: int)

const BOND_PER_LEVEL := 30.0
const MAX_BOND_LEVEL := 5

var max_hunger: float = 100.0
var max_happiness: float = 100.0
var max_energy: float = 100.0

var hunger: float = 70.0
var happiness: float = 70.0
var energy: float = 80.0
var bond: float = 0.0  # total bond points


func setup(species: CreatureSpecies) -> void:
	max_hunger = species.max_hunger
	max_happiness = species.max_happiness
	max_energy = species.max_energy
	hunger = max_hunger * 0.7
	happiness = max_happiness * 0.7
	energy = max_energy * 0.8
	bond = 0.0
	changed.emit()


func add_hunger(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, max_hunger)
	changed.emit()


func add_happiness(amount: float) -> void:
	happiness = clampf(happiness + amount, 0.0, max_happiness)
	changed.emit()


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	changed.emit()


func add_bond(amount: float) -> void:
	var old_level := get_bond_level()
	bond = clampf(bond + amount, 0.0, _max_bond_points())
	var new_level := get_bond_level()
	if new_level > old_level:
		bond_level_changed.emit(new_level)
	changed.emit()


func get_bond_level() -> int:
	return mini(1 + int(bond / BOND_PER_LEVEL), MAX_BOND_LEVEL)


## 0.0 to 1.0 progress toward the next bond level (1.0 at max level).
func get_bond_progress() -> float:
	var level := get_bond_level()
	if level >= MAX_BOND_LEVEL:
		return 1.0
	return (bond - (level - 1) * BOND_PER_LEVEL) / BOND_PER_LEVEL


## Plain values for the save file.
func to_dict() -> Dictionary:
	return {"hunger": hunger, "happiness": happiness, "energy": energy, "bond": bond}


## Restores saved values (clamped to this species' maximums). Does NOT emit
## bond_level_changed, so loading never shows a "level up" message.
func load_dict(data: Dictionary) -> void:
	hunger = clampf(float(data.get("hunger", hunger)), 0.0, max_hunger)
	happiness = clampf(float(data.get("happiness", happiness)), 0.0, max_happiness)
	energy = clampf(float(data.get("energy", energy)), 0.0, max_energy)
	bond = clampf(float(data.get("bond", 0.0)), 0.0, _max_bond_points())
	changed.emit()


func _max_bond_points() -> float:
	return (MAX_BOND_LEVEL - 1) * BOND_PER_LEVEL
