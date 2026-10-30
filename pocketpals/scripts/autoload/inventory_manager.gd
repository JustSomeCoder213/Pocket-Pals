extends Node

## What the player owns. Registered as an autoload named "InventoryManager".
## Item IDs are plain Strings and match ItemData.item_id, e.g. "basic_food".

signal inventory_changed
signal bed_changed(bed_id: String)
signal toy_changed(toy_id: String)
signal decorations_changed

const DEFAULT_ITEMS := {"basic_food": 5, "basic_bed": 1, "basic_toy": 1}
const DEFAULT_BED := "basic_bed"
const DEFAULT_TOY := "basic_toy"
## Always owned, even if a save file claims otherwise (they are the free starting gear).
const ALWAYS_OWNED := ["basic_bed", "basic_toy"]

var items: Dictionary = {}  # item_id (String) -> count (int)
var equipped_bed: String = DEFAULT_BED
var equipped_toy: String = DEFAULT_TOY
var placed_decorations: Dictionary = {}  # slot name (String) -> item_id (String)


func _ready() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	items = DEFAULT_ITEMS.duplicate()
	equipped_bed = DEFAULT_BED
	equipped_toy = DEFAULT_TOY
	placed_decorations = {}
	_emit_all()


func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


func add_item(item_id: String, amount: int = 1) -> void:
	items[item_id] = get_count(item_id) + amount
	inventory_changed.emit()


## Returns true if the items were removed, false if the player doesn't have enough.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	items[item_id] = get_count(item_id) - amount
	inventory_changed.emit()
	return true


func set_equipped_bed(bed_id: String) -> void:
	equipped_bed = bed_id
	bed_changed.emit(equipped_bed)


func set_equipped_toy(toy_id: String) -> void:
	equipped_toy = toy_id
	toy_changed.emit(equipped_toy)


## Puts a decoration in a slot, replacing whatever was there.
func place_decoration(slot: String, item_id: String) -> void:
	placed_decorations[slot] = item_id
	decorations_changed.emit()


func remove_decoration(slot: String) -> void:
	if placed_decorations.erase(slot):
		decorations_changed.emit()


func is_placed(item_id: String) -> bool:
	return placed_decorations.values().has(item_id)


# ---------- Saving and loading ----------

func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"equipped_bed": equipped_bed,
		"equipped_toy": equipped_toy,
		"placed_decorations": placed_decorations.duplicate(),
	}


## Restores saved inventory. Returns false (and changes nothing) if the data is unusable.
## Unknown items are dropped, and invalid equipment falls back to the starting gear.
func from_dict(data: Dictionary) -> bool:
	var raw_items: Variant = data.get("items")
	if not (raw_items is Dictionary):
		return false

	var loaded_items: Dictionary = {}
	for key in raw_items:
		var value: Variant = raw_items[key]
		var count := 0
		if value is int or value is float:
			count = int(value)
		var item := ItemDatabase.get_item(str(key))
		if item == null or count <= 0:
			continue  # unknown (removed from the game?) or empty: drop it
		if item.is_consumable():
			loaded_items[str(key)] = count
		else:
			loaded_items[str(key)] = 1  # permanent and reusable items are owned once
	for item_id in ALWAYS_OWNED:
		loaded_items[item_id] = 1

	var bed_id := str(data.get("equipped_bed", DEFAULT_BED))
	var bed := ItemDatabase.get_item(bed_id)
	if bed == null or bed.category != "Sleep" or not loaded_items.has(bed_id):
		bed_id = DEFAULT_BED

	var toy_id := str(data.get("equipped_toy", DEFAULT_TOY))
	var toy := ItemDatabase.get_item(toy_id)
	if toy == null or toy.category != "Toy" or not loaded_items.has(toy_id):
		toy_id = DEFAULT_TOY

	var loaded_decorations: Dictionary = {}
	var raw_decorations: Variant = data.get("placed_decorations")
	if raw_decorations is Dictionary:
		for slot in raw_decorations:
			var decoration_id := str(raw_decorations[slot])
			var decoration := ItemDatabase.get_item(decoration_id)
			if decoration == null or decoration.category != "Decoration":
				continue
			if decoration.decor_slot != str(slot) or not loaded_items.has(decoration_id):
				continue
			loaded_decorations[str(slot)] = decoration_id

	items = loaded_items
	equipped_bed = bed_id
	equipped_toy = toy_id
	placed_decorations = loaded_decorations
	_emit_all()
	return true


func _emit_all() -> void:
	inventory_changed.emit()
	bed_changed.emit(equipped_bed)
	toy_changed.emit(equipped_toy)
	decorations_changed.emit()
