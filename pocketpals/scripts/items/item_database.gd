class_name ItemDatabase
extends RefCounted

## Static lookup for item definitions:
##   ItemDatabase.get_item("basic_food")
##   ItemDatabase.get_items_in_category("Sleep")

const ITEMS_DIR := "res://resources/items"

static var _items: Dictionary = {}  # item_id (String) -> ItemData
static var _loaded: bool = false


static func get_item(item_id: String) -> ItemData:
	_ensure_loaded()
	return _items.get(item_id) as ItemData


static func get_all_items() -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for item in _items.values():
		result.append(item)
	return result


## Items of one category ("Food", "Sleep", "Toy", "Decoration"), cheapest first.
static func get_items_in_category(category: String) -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for item in _items.values():
		if item.category == category:
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.price != b.price:
			return a.price < b.price
		return a.display_name < b.display_name
	)
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("ItemDatabase: cannot open folder %s" % ITEMS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Exported games list resources as "name.tres.remap"; strip that suffix.
			var clean_name := file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var path := "%s/%s" % [ITEMS_DIR, clean_name]
				var item := load(path) as ItemData
				if item == null or item.item_id == "":
					push_warning("ItemDatabase: %s is not a valid ItemData (missing item_id?)" % path)
				else:
					_items[item.item_id] = item
		file_name = dir.get_next()
	dir.list_dir_end()
