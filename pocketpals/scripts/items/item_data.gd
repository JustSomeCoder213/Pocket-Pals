class_name ItemData
extends Resource

## One file of this type = one shop item. To add an item: copy any .tres file in
## res://resources/items/, change item_id and the values, and save. No code changes.

@export var item_id: String = ""
@export var display_name: String = "Item"
@export_enum("Food", "Sleep", "Toy", "Decoration") var category: String = "Food"
@export var price: int = 10
@export_multiline var description: String = ""
## Consumable = used up, can be bought again.
## Reusable / Permanent = bought once and kept (toys / beds and decorations).
@export_enum("Consumable", "Reusable", "Permanent") var usage: String = "Consumable"

@export_group("Food and toy effects")
@export var hunger_restore: float = 0.0
@export var energy_restore: float = 0.0
@export var happiness_gain: float = 0.0  ## also the Play happiness for toys
@export var bond_gain: float = 0.0       ## also the Play bond for toys
@export var energy_cost: float = 0.0     ## toys only: energy spent per Play

@export_group("Sleep effects (per care tick)")
@export var energy_per_tick: float = 0.0
@export var happiness_per_tick: float = 0.0

@export_group("Appearance")
@export var color: Color = Color(0.8, 0.8, 0.8)
@export var accent_color: Color = Color(0.5, 0.4, 0.3)
@export var model_scale: float = 1.0
@export_enum("plant", "rug", "painting", "lamp") var visual: String = "plant"
@export_enum("rug", "plant", "wall", "lamp") var decor_slot: String = "rug"


func is_consumable() -> bool:
	return usage == "Consumable"


func get_usage_text() -> String:
	match usage:
		"Consumable":
			return "Used up when fed. Buy as many as you like."
		"Reusable":
			return "Buy once, play with it as often as you like."
	return "Buy once, keep forever."


func get_effect_text() -> String:
	var parts: PackedStringArray = []
	match category:
		"Food":
			if hunger_restore > 0.0:
				parts.append("Hunger +%s" % _n(hunger_restore))
			if energy_restore > 0.0:
				parts.append("Energy +%s" % _n(energy_restore))
			if happiness_gain > 0.0:
				parts.append("Happiness +%s" % _n(happiness_gain))
			if bond_gain > 0.0:
				parts.append("Bond +%s" % _n(bond_gain))
		"Sleep":
			parts.append("Energy +%s every 5 s while resting" % _n(energy_per_tick))
			if happiness_per_tick > 0.0:
				parts.append("Happiness +%s every 5 s" % _n(happiness_per_tick))
		"Toy":
			parts.append("Play: Happiness +%s, Bond +%s, Energy -%s" % [_n(happiness_gain), _n(bond_gain), _n(energy_cost)])
		"Decoration":
			parts.append("Decorates the %s spot" % decor_slot)
	return ", ".join(parts)


func _n(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")
