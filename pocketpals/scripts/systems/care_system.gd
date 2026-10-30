class_name CareSystem
extends Node

## The ONE place where creature needs change over time, and where all care
## actions are validated. UI buttons call feed()/pet()/play()/rest()/wake().
## Other nodes react through the two signals below.
##
## Needs only change while the game is running (no offline progression).

## Text for the status line, e.g. "Mochi ate Basic Food."
signal message(text: String)
## Which animation to trigger: &"feed", &"pet", &"play", &"rest", &"wake"
signal action_done(action: StringName)

## "Low" means below this fraction of the maximum.
const LOW_RATIO := 0.25

@export_group("Time")
@export var tick_interval: float = 5.0  ## seconds between needs updates
@export var time_scale: float = 1.0  ## 10.0 = ten times faster (debug F1)

@export_group("Passive rates (per tick)")
@export var hunger_loss_per_tick: float = 1.0
@export var sleeping_hunger_multiplier: float = 0.5
@export var happiness_loss_content: float = 0.1
@export var happiness_loss_neglected: float = 0.5
@export var min_happiness_ratio: float = 0.2  ## passive decay never goes below this

@export_group("Actions")
@export var pet_happiness: float = 8.0
@export var pet_bond: float = 2.0
## Fallback values used only if the equipped toy can't be found.
@export var play_happiness: float = 12.0
@export var play_bond: float = 3.0
@export var play_energy_cost: float = 15.0
@export var auto_rest_ratio: float = 0.1  ## below this energy after playing, the creature naps by itself

var species: CreatureSpecies
var stats: CreatureStats
var sleep: SleepSystem

var _accumulator: float = 0.0


func setup(p_species: CreatureSpecies) -> void:
	species = p_species
	stats = CreatureStats.new()
	stats.setup(species)
	stats.bond_level_changed.connect(_on_bond_level_changed)
	sleep = SleepSystem.new()
	sleep.rest_started.connect(_on_rest_started)
	sleep.rest_ended.connect(_on_rest_ended)


func _process(delta: float) -> void:
	if stats == null:
		return
	_accumulator += delta * time_scale
	while _accumulator >= tick_interval:
		_accumulator -= tick_interval
		_tick()


# ---------- Queries ----------

func is_hungry() -> bool:
	return stats.hunger < stats.max_hunger * LOW_RATIO


func is_tired() -> bool:
	return stats.energy < stats.max_energy * LOW_RATIO


# ---------- Actions (return true if the action happened) ----------

func feed(food_id: String = "basic_food") -> bool:
	if _refuse_if_sleeping():
		return false
	var food := ItemDatabase.get_item(food_id)
	if food == null or food.category != "Food":
		message.emit("%s can't eat that." % species.display_name)
		return false
	# A food is only useful if it restores something that isn't already full.
	var helps_hunger := food.hunger_restore > 0.0 and stats.hunger < stats.max_hunger - 0.01
	var helps_energy := food.energy_restore > 0.0 and stats.energy < stats.max_energy - 0.01
	if not helps_hunger and not helps_energy:
		message.emit("%s doesn't need %s right now." % [species.display_name, food.display_name])
		return false
	if not InventoryManager.remove_item(food_id):
		message.emit("You're out of %s!" % food.display_name)
		return false
	stats.add_hunger(food.hunger_restore)
	stats.add_energy(food.energy_restore)
	stats.add_happiness(food.happiness_gain)
	stats.add_bond(food.bond_gain)
	message.emit("%s enjoyed %s! (%s)" % [species.display_name, food.display_name, food.get_effect_text()])
	action_done.emit(&"feed")
	return true


func pet() -> bool:
	if _refuse_if_sleeping():
		return false
	stats.add_happiness(pet_happiness)
	stats.add_bond(pet_bond)
	message.emit("%s loves the cuddles! (Happiness +%d)" % [species.display_name, int(pet_happiness)])
	action_done.emit(&"pet")
	return true


func play() -> bool:
	if _refuse_if_sleeping():
		return false
	var happiness_base := play_happiness
	var bond_gain := play_bond
	var energy_cost := play_energy_cost
	var toy_name := "playing"
	var toy := ItemDatabase.get_item(InventoryManager.equipped_toy)
	if toy != null and toy.category == "Toy":
		happiness_base = toy.happiness_gain
		bond_gain = toy.bond_gain
		energy_cost = toy.energy_cost
		toy_name = "the %s" % toy.display_name
	if stats.energy < energy_cost:
		message.emit("%s is too tired to play. Let it rest first." % species.display_name)
		return false
	var happiness_gain := happiness_base * (0.5 if is_hungry() else 1.0)
	stats.add_energy(-energy_cost)
	stats.add_happiness(happiness_gain)
	stats.add_bond(bond_gain)
	message.emit("%s had fun with %s! (Happiness +%d, Energy -%d)" % [species.display_name, toy_name, int(happiness_gain), int(energy_cost)])
	action_done.emit(&"play")
	# Worn out? Take a nap automatically. Not a punishment, just cozy.
	if stats.energy < stats.max_energy * auto_rest_ratio:
		sleep.start_rest()
	return true


func rest() -> bool:
	if sleep.is_resting:
		return false
	if stats.energy >= stats.max_energy - 0.01:
		message.emit("%s isn't sleepy right now." % species.display_name)
		return false
	sleep.start_rest()
	return true


func wake() -> void:
	sleep.stop_rest()


# ---------- Internals ----------

func _tick() -> void:
	var hunger_loss := hunger_loss_per_tick
	if sleep.is_resting:
		hunger_loss *= sleeping_hunger_multiplier
	stats.add_hunger(-hunger_loss)
	sleep.apply_tick(stats, InventoryManager.equipped_bed)
	_apply_happiness_decay()


func _apply_happiness_decay() -> void:
	if sleep.is_resting:
		return  # a sleeping creature stays content
	var floor_value := stats.max_happiness * min_happiness_ratio
	if stats.happiness <= floor_value:
		return
	var neglected := is_hungry() or is_tired()
	var loss: float = happiness_loss_neglected if neglected else happiness_loss_content
	stats.add_happiness(-minf(loss, stats.happiness - floor_value))


func _refuse_if_sleeping() -> bool:
	if sleep.is_resting:
		message.emit("%s is sleeping. Wake it up first." % species.display_name)
		return true
	return false


func _on_rest_started() -> void:
	action_done.emit(&"rest")
	message.emit("%s curled up for a rest. Zzz..." % species.display_name)


func _on_rest_ended() -> void:
	action_done.emit(&"wake")
	if stats.energy >= stats.max_energy - 0.01:
		message.emit("%s woke up fully rested!" % species.display_name)
	else:
		message.emit("%s woke up." % species.display_name)


func _on_bond_level_changed(new_level: int) -> void:
	message.emit("Bond level up! You and %s are now Lv %d friends." % [species.display_name, new_level])
