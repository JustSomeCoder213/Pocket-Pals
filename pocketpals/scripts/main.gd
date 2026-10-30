extends Node

## Assembles the game and owns mode switching, saving and the start-up flow.
##
## BUILD ORDER:
## 1. Load the save file (if any)
## 2. CareSystem, Economy, DiscoverySystem   (plain logic, no visuals)
## 3. Home, Outdoor                          (the two locations)
## 4. PhotoCamera                            (drives whichever location's camera is active)
## 5. HUDs, Shop, Collection, Menu, Intro   (listen to everything through signals)
## 6. Apply the save, then either start the game or play the professor's intro
##
## MODES:  INTRO is the professor's welcome (new games only).
##         HOME <-> OUTDOOR are the two locations.
##         CAMERA can be entered from either and returns to where it came from.
##         Shop, Collection and Menu are overlays on top of HOME / OUTDOOR (not modes).
##
## SAVING: nothing is saved until the starter has been accepted. After that, any change
## to coins, items or discoveries triggers a save about 1.5 s later; a save also happens
## every 30 s, from the menu, and when the window closes.

const HomeScript := preload("res://scripts/world/home_controller.gd")
const HudScript := preload("res://scripts/ui/main_hud.gd")
const CameraHudScript := preload("res://scripts/ui/camera_hud.gd")
const PhotoResultScript := preload("res://scripts/ui/photo_result.gd")
const ShopScript := preload("res://scripts/ui/shop.gd")
const STARTER_SPECIES_PATH := "res://resources/creatures/mochi.tres"

const AUTOSAVE_SECONDS := 30.0
const SAVE_DEBOUNCE_SECONDS := 1.5

## Set to false to disable the F1-F7 testing shortcuts.
const DEBUG_KEYS_ENABLED := true
const BED_ORDER := ["basic_bed", "improved_bed", "premium_mat"]

var care: CareSystem
var economy: Economy
var discovery: DiscoverySystem
var home: Node3D
var outdoor: OutdoorController
var photo_camera: PhotoCamera
var hud: CanvasLayer
var nav_hud: NavHud
var camera_hud: CanvasLayer
var photo_result: CanvasLayer
var shop: CanvasLayer
var collection: CollectionScreen
var tutorial: TutorialPrompts
var menu: GameMenu
var intro: IntroDialogue
var audio: AudioHooks

var _species: CreatureSpecies
var _starter_granted := false
var _saving_enabled := false
var _dirty := false
var _debounce := 0.0
var _since_save := 0.0
var _camera_return_mode: GameManager.Mode = GameManager.Mode.HOME


func _ready() -> void:
	var starter := load(STARTER_SPECIES_PATH) as CreatureSpecies
	if starter == null:
		push_error("Could not load starter species at %s" % STARTER_SPECIES_PATH)
		return
	_species = starter

	# 1. The save file (empty Dictionary = fresh game).
	var save := SaveManager.load_game()
	if not save.is_empty():
		var saved_species := SpeciesDatabase.get_species(str(save["companion"]["species_id"]))
		if saved_species != null and saved_species.habitat == "Home":
			_species = saved_species

	# 2. Plain logic.
	care = CareSystem.new()
	care.name = "CareSystem"
	add_child(care)
	care.setup(_species)

	economy = Economy.new()

	discovery = DiscoverySystem.new()
	discovery.setup(_species)

	# 3. The two locations.
	home = Node3D.new()
	home.name = "Home"
	home.set_script(HomeScript)
	add_child(home)
	home.setup(_species, care)

	outdoor = OutdoorController.new()
	outdoor.name = "Outdoor"
	add_child(outdoor)
	outdoor.setup(SpeciesDatabase.get_wild_species())
	outdoor.set_active(false)  # hidden and frozen until the player walks out

	# 4. Camera Mode logic.
	photo_camera = PhotoCamera.new()
	photo_camera.name = "PhotoCamera"
	add_child(photo_camera)
	photo_camera.setup(home.camera)

	# 5. Interface.
	hud = CanvasLayer.new()
	hud.name = "MainHUD"
	hud.set_script(HudScript)
	add_child(hud)
	hud.setup(_species, care)

	nav_hud = NavHud.new()
	nav_hud.name = "NavHUD"
	add_child(nav_hud)
	nav_hud.setup(discovery)

	tutorial = TutorialPrompts.new()
	tutorial.name = "TutorialPrompts"
	add_child(tutorial)
	tutorial.setup(care, photo_camera, economy, discovery, _species.display_name)

	camera_hud = CanvasLayer.new()
	camera_hud.name = "CameraHUD"
	camera_hud.layer = 2
	camera_hud.set_script(CameraHudScript)
	add_child(camera_hud)
	camera_hud.setup(photo_camera)

	shop = CanvasLayer.new()
	shop.name = "Shop"
	shop.layer = 2
	shop.set_script(ShopScript)
	add_child(shop)
	shop.setup(economy)

	collection = CollectionScreen.new()
	collection.name = "Collection"
	collection.layer = 2
	add_child(collection)
	collection.setup(discovery)

	photo_result = CanvasLayer.new()
	photo_result.name = "PhotoResult"
	photo_result.layer = 3
	photo_result.set_script(PhotoResultScript)
	add_child(photo_result)

	menu = GameMenu.new()
	menu.name = "GameMenu"
	menu.layer = 3
	add_child(menu)

	intro = IntroDialogue.new()
	intro.name = "IntroDialogue"
	intro.layer = 4
	add_child(intro)

	audio = AudioHooks.new()
	audio.name = "AudioHooks"
	add_child(audio)
	audio.setup(care, economy, discovery, photo_camera)

	# Wiring: UI scripts only emit signals, this script decides what happens.
	hud.camera_requested.connect(_enter_camera_mode)
	hud.shop_requested.connect(_open_shop)
	nav_hud.outdoors_requested.connect(_go_outdoors)
	nav_hud.home_requested.connect(_go_home)
	nav_hud.camera_requested.connect(_enter_camera_mode)
	nav_hud.collection_requested.connect(_open_collection)
	camera_hud.photo_requested.connect(photo_camera.take_photo)
	camera_hud.recenter_requested.connect(photo_camera.find_next_subject)
	camera_hud.exit_requested.connect(_exit_camera_mode)
	photo_camera.photo_taken.connect(_on_photo_taken)
	photo_result.closed.connect(_on_photo_result_closed)
	intro.starter_accepted.connect(_on_starter_accepted)
	menu.save_requested.connect(_on_menu_save)
	menu.reset_requested.connect(_on_menu_reset)
	menu.quit_requested.connect(_on_menu_quit)

	# Anything that should trigger a save marks the game "dirty".
	GameManager.coins_changed.connect(_mark_dirty.unbind(1))
	InventoryManager.inventory_changed.connect(_mark_dirty)
	InventoryManager.bed_changed.connect(_mark_dirty.unbind(1))
	InventoryManager.toy_changed.connect(_mark_dirty.unbind(1))
	InventoryManager.decorations_changed.connect(_mark_dirty)
	discovery.changed.connect(_mark_dirty)
	tutorial.step_changed.connect(_mark_dirty.unbind(1))

	# 6. Apply the save, then start.
	var tutorial_step := 0
	if not save.is_empty():
		_apply_save(save)
		_starter_granted = bool(save["starter_granted"])
		tutorial_step = int(save["tutorial"]["step"])
	_dirty = false

	if _starter_granted:
		_begin_game(tutorial_step)
	else:
		_begin_intro()


# ---------- Start-up flow ----------

## New game: the professor talks, and the creature stays hidden until it is gifted.
func _begin_intro() -> void:
	_saving_enabled = false
	GameManager.set_mode(GameManager.Mode.INTRO)
	care.process_mode = Node.PROCESS_MODE_DISABLED  # needs don't tick before the gift
	home.creature.visible = false
	intro.start(_species)


## The ONLY place the starter gift is granted: the Accept button in the intro.
func _on_starter_accepted() -> void:
	_starter_granted = true
	care.process_mode = Node.PROCESS_MODE_INHERIT
	home.creature.visible = true
	home.creature.react_happy()
	_begin_game(0)


func _begin_game(tutorial_step: int) -> void:
	_saving_enabled = true
	GameManager.set_mode(GameManager.Mode.HOME)
	tutorial.start(tutorial_step)
	_save_now()  # creates the file for a new game, and heals a recovered one
	if SaveManager.last_load_note != "":
		care.message.emit(SaveManager.last_load_note)
		push_warning(SaveManager.last_load_note)


# ---------- Saving and loading ----------

func _apply_save(save: Dictionary) -> void:
	GameManager.set_coins(int(save["coins"]))
	InventoryManager.from_dict(save["inventory"])
	care.stats.load_dict(save["creature"])
	discovery.from_dict(save["discovery"])


func _collect_save() -> Dictionary:
	return {
		"starter_granted": _starter_granted,
		"tutorial": {"step": tutorial.get_step()},
		"coins": GameManager.coins,
		"companion": {"species_id": str(_species.species_id)},
		"creature": care.stats.to_dict(),
		"inventory": InventoryManager.to_dict(),
		"discovery": discovery.to_dict(),
	}


func _mark_dirty() -> void:
	_dirty = true


## Writes the save now. Returns true on success. Does nothing before the starter is accepted.
func _save_now() -> bool:
	if not _saving_enabled:
		return false
	_debounce = 0.0
	_since_save = 0.0
	var ok := SaveManager.save_game(_collect_save())
	_dirty = not ok  # on failure, try again soon
	return ok


func _process(delta: float) -> void:
	if not _saving_enabled:
		return
	_since_save += delta
	if _dirty:
		_debounce += delta
		if _debounce >= SAVE_DEBOUNCE_SECONDS:
			_save_now()
	elif _since_save >= AUTOSAVE_SECONDS:
		_save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()


# ---------- Menu actions ----------

func _on_menu_save() -> void:
	if not _saving_enabled:
		menu.set_status("Nothing to save yet.")
	elif _save_now():
		menu.set_status("Game saved at %s." % Time.get_time_string_from_system())
	else:
		menu.set_status("Saving failed: %s" % SaveManager.last_error)


func _on_menu_quit() -> void:
	_save_now()
	get_tree().quit()


## Erases the save and restarts from the professor's introduction.
func _on_menu_reset() -> void:
	_saving_enabled = false  # nothing may re-create the file while we reset
	SaveManager.delete_save()
	GameManager.set_coins(0)
	InventoryManager.reset_to_defaults()
	GameManager.set_mode(GameManager.Mode.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


# ---------- Mode switching ----------

func _overlay_open() -> bool:
	return shop.visible or collection.visible or menu.visible


func _go_outdoors() -> void:
	if GameManager.current_mode != GameManager.Mode.HOME or _overlay_open():
		return
	_set_location(true)
	GameManager.set_mode(GameManager.Mode.OUTDOOR)


func _go_home() -> void:
	if GameManager.current_mode != GameManager.Mode.OUTDOOR or _overlay_open():
		return
	_set_location(false)
	GameManager.set_mode(GameManager.Mode.HOME)


## Shows one location, hides the other, and points PhotoCamera at the right Camera3D.
func _set_location(outdoors: bool) -> void:
	home.visible = not outdoors  # also hides the home's lights
	outdoor.set_active(outdoors)  # also makes the outdoor camera current
	if outdoors:
		photo_camera.set_camera(outdoor.camera, outdoor.pan_limit)
	else:
		home.camera.current = true
		photo_camera.set_camera(home.camera)


func _enter_camera_mode() -> void:
	var mode := GameManager.current_mode
	if (mode != GameManager.Mode.HOME and mode != GameManager.Mode.OUTDOOR) or _overlay_open():
		return
	_camera_return_mode = mode
	GameManager.set_mode(GameManager.Mode.CAMERA)
	photo_camera.enter()


func _exit_camera_mode() -> void:
	if GameManager.current_mode != GameManager.Mode.CAMERA:
		return
	photo_camera.exit()
	GameManager.set_mode(_camera_return_mode)


func _toggle_camera_mode() -> void:
	if photo_camera.input_blocked or _overlay_open():
		return  # the result panel, the shop, the collection or the menu is open
	if GameManager.current_mode == GameManager.Mode.CAMERA:
		_exit_camera_mode()
	else:
		_enter_camera_mode()


## The shop is an overlay on top of Home mode (not a separate mode).
func _open_shop() -> void:
	if GameManager.current_mode != GameManager.Mode.HOME or _overlay_open():
		return
	shop.open()


## The collection is an overlay on top of Home or Outdoor mode.
func _open_collection() -> void:
	var mode := GameManager.current_mode
	if (mode != GameManager.Mode.HOME and mode != GameManager.Mode.OUTDOOR) or _overlay_open():
		return
	collection.open()


func _open_menu() -> void:
	var mode := GameManager.current_mode
	if (mode != GameManager.Mode.HOME and mode != GameManager.Mode.OUTDOOR) or _overlay_open():
		return
	menu.open()


# ---------- Photo results ----------

func _on_photo_taken(result: Dictionary) -> void:
	if not result["valid"]:
		return  # CameraHUD shows the reason as a short message; no reward.
	# DiscoverySystem decides if this is a first discovery and adds the one-time bonus.
	var final_result := discovery.register_photo(result)
	GameManager.add_coins(int(final_result["coins"]))
	photo_camera.input_blocked = true
	photo_result.show_result(final_result)


func _on_photo_result_closed() -> void:
	photo_camera.input_blocked = false


# ---------- Input ----------

func _debug(text: String) -> void:
	print("DEBUG: ", text)
	care.message.emit("DEBUG: " + text)


func _unhandled_input(event: InputEvent) -> void:
	if care == null:
		return
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera_mode()
		return
	if event.is_action_pressed("open_shop"):
		_open_shop()  # closing is handled by the shop itself
		return
	if event.is_action_pressed("open_collection"):
		_open_collection()  # closing is handled by the collection itself
		return
	if event.is_action_pressed("go_outdoor"):
		_go_outdoors()
		return
	if event.is_action_pressed("go_home"):
		_go_home()
		return
	if event.is_action_pressed("ui_cancel"):
		_open_menu()  # closing is handled by the menu itself
		return

	if not DEBUG_KEYS_ENABLED:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:  # toggle fast time
			care.time_scale = 1.0 if care.time_scale > 1.0 else 10.0
			care.message.emit("DEBUG: time speed x%d" % int(care.time_scale))
		KEY_F2:  # cycle through bed types (ignores ownership, for testing)
			var index := BED_ORDER.find(InventoryManager.equipped_bed)
			var next_id: String = BED_ORDER[(index + 1) % BED_ORDER.size()]
			InventoryManager.set_equipped_bed(next_id)
			var bed_name: String = care.sleep.get_bed_data(next_id)["name"]
			care.message.emit("DEBUG: equipped %s" % bed_name)
		KEY_F3:  # supplies
			InventoryManager.add_item("basic_food", 5)
			GameManager.add_coins(100)
			care.message.emit("DEBUG: +5 Basic Food, +100 coins")
		KEY_F4:  # make hungry and tired (to test resting)
			care.stats.add_hunger(20.0 - care.stats.hunger)
			care.stats.add_energy(20.0 - care.stats.energy)
			care.message.emit("DEBUG: hunger and energy set to 20")
		KEY_F5:  # fill every empty spawn point right now, rare species included
			outdoor.spawner.force_spawn_all()
			_debug("spawned a creature at every free spawn point")
		KEY_F6:  # forget all discoveries (the starter stays)
			discovery.reset()
			_debug("collection reset")
		KEY_F7:  # save right now and print where the file is
			var saved := _save_now()
			_debug("save %s -> %s" % ["ok" if saved else "FAILED", SaveManager.get_save_folder()])
