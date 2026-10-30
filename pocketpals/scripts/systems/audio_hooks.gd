class_name AudioHooks
extends Node

## Sound effects without any audio files. Each sound is a list of [frequency in Hz,
## seconds] notes (frequency 0 = a burst of noise).
##
## TO USE REAL SOUNDS: put a file named after the sound (for example "shutter.ogg") into
## res://assets/audio/. It replaces the generated one. Supported: .ogg .wav .mp3.
## TO ADD A SOUND: add an entry to SOUNDS and call play("<name>") from setup().

const OVERRIDE_DIR := "res://assets/audio"
const MIX_RATE := 22050
const SOUNDS := {
	"feed": {"notes": [[392.0, 0.06], [523.0, 0.10]], "volume": 0.40},
	"pet": {"notes": [[523.0, 0.08], [659.0, 0.12]], "volume": 0.35},
	"play": {"notes": [[440.0, 0.05], [554.0, 0.05], [659.0, 0.05], [880.0, 0.10]], "volume": 0.35},
	"rest": {"notes": [[330.0, 0.15], [262.0, 0.25]], "volume": 0.30},
	"shutter": {"notes": [[0.0, 0.03], [1200.0, 0.02], [0.0, 0.06]], "volume": 0.45},
	"error": {"notes": [[180.0, 0.12], [140.0, 0.18]], "volume": 0.35},
	"buy": {"notes": [[880.0, 0.07], [1320.0, 0.14]], "volume": 0.35},
	"discover": {"notes": [[523.0, 0.10], [659.0, 0.10], [784.0, 0.10], [1047.0, 0.25]], "volume": 0.40},
	"levelup": {"notes": [[659.0, 0.10], [880.0, 0.10], [1175.0, 0.20]], "volume": 0.40},
}

var _players: Dictionary = {}  # sound name (String) -> AudioStreamPlayer


func _ready() -> void:
	for sound_name in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.name = "Sound_%s" % sound_name
		player.stream = _make_stream(str(sound_name))
		player.volume_db = -6.0
		add_child(player)
		_players[str(sound_name)] = player


## Called by main.gd after this node is in the tree.
func setup(care: CareSystem, economy: Economy, discovery: DiscoverySystem, photo_camera: PhotoCamera) -> void:
	care.action_done.connect(_on_care_action)
	care.stats.bond_level_changed.connect(func(_level: int) -> void: play("levelup"))
	economy.purchased.connect(func(_item_id: String) -> void: play("buy"))
	discovery.species_discovered.connect(_on_species_discovered)
	photo_camera.photo_taken.connect(_on_photo_taken)


func play(sound_name: String) -> void:
	var player := _players.get(sound_name) as AudioStreamPlayer
	if player != null:
		player.play()


# ---------- Event handlers ----------

func _on_care_action(action: StringName) -> void:
	match action:
		&"feed":
			play("feed")
		&"pet":
			play("pet")
		&"play":
			play("play")
		&"rest":
			play("rest")


func _on_photo_taken(result: Dictionary) -> void:
	play("shutter" if result["valid"] else "error")


func _on_species_discovered(_species_id: String) -> void:
	# Slightly delayed so the shutter sound isn't drowned out.
	get_tree().create_timer(0.3).timeout.connect(play.bind("discover"))


# ---------- Sound creation ----------

func _make_stream(sound_name: String) -> AudioStream:
	for extension in ["ogg", "wav", "mp3"]:
		var path := "%s/%s.%s" % [OVERRIDE_DIR, sound_name, extension]
		if ResourceLoader.exists(path):
			var custom := load(path) as AudioStream
			if custom != null:
				return custom
	var recipe: Dictionary = SOUNDS[sound_name]
	return _synthesize(recipe["notes"], float(recipe["volume"]))


## Builds a 16-bit mono sound from notes. A short fade-in and a linear fade-out avoid clicks.
func _synthesize(notes: Array, volume: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	for note in notes:
		var frequency: float = note[0]
		var count := int(MIX_RATE * float(note[1]))
		var start := bytes.size()
		bytes.resize(start + count * 2)
		var phase := 0.0
		for i in count:
			var t := float(i) / float(count)
			var envelope := minf(t * 20.0, 1.0) * (1.0 - t)
			var value := 0.0
			if frequency > 0.0:
				phase += TAU * frequency / MIX_RATE
				value = sin(phase)
			else:
				value = randf_range(-1.0, 1.0)
			var sample := int(clampf(value * envelope * volume, -1.0, 1.0) * 32767.0)
			bytes.encode_s16(start + i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
