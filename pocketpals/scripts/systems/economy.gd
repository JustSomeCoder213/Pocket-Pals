class_name Economy
extends RefCounted

## Purchase and equip rules. The shop UI calls these and shows the message.

## Emitted after a successful purchase (tutorial and sound hooks listen to this).
signal purchased(item_id: String)


func purchase(item_id: String) -> Dictionary:
	var item := ItemDatabase.get_item(item_id)
	if item == null:
		return _result(false, "That item doesn't exist.")
	if not item.is_consumable() and InventoryManager.has_item(item_id):
		return _result(false, "You already own %s." % item.display_name)
	if GameManager.coins < item.price:
		return _result(false, "Not enough coins! %s costs %d and you have %d." % [item.display_name, item.price, GameManager.coins])

	GameManager.add_coins(-item.price)
	InventoryManager.add_item(item_id)
	purchased.emit(item_id)

	if item.is_consumable():
		return _result(true, "Bought %s! You now have %d." % [item.display_name, InventoryManager.get_count(item_id)])
	# Equipment and decorations are put to use right away.
	var use_result := use_owned(item)
	return _result(true, "Bought %s! %s" % [item.display_name, use_result["message"]])


## Equips a bed or toy, or toggles a decoration on/off. The item must be owned.
func use_owned(item: ItemData) -> Dictionary:
	if not InventoryManager.has_item(item.item_id):
		return _result(false, "You don't own %s yet." % item.display_name)
	match item.category:
		"Sleep":
			InventoryManager.set_equipped_bed(item.item_id)
			return _result(true, "%s is now your companion's bed." % item.display_name)
		"Toy":
			InventoryManager.set_equipped_toy(item.item_id)
			return _result(true, "%s is now the favorite toy." % item.display_name)
		"Decoration":
			if InventoryManager.is_placed(item.item_id):
				InventoryManager.remove_decoration(item.decor_slot)
				return _result(true, "Removed %s from the room." % item.display_name)
			InventoryManager.place_decoration(item.decor_slot, item.item_id)
			return _result(true, "Placed %s in the room." % item.display_name)
	return _result(false, "%s can't be equipped." % item.display_name)


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
