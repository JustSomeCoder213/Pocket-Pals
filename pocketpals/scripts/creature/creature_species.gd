class_name CreatureSpecies
extends Resource

## One file of this type = one creature species. No code changes needed
## to add a new species: duplicate a .tres file and edit the values.

@export var species_id: StringName = &"unknown"
@export var display_name: String = "Unknown"
@export_multiline var description: String = ""
@export_enum("Common", "Uncommon", "Rare") var rarity: String = "Common"
@export_enum("Home", "Forest", "Meadow", "Rocks") var habitat: String = "Home"
## Position in the collection screen (lower = earlier). Ties are sorted by name.
@export var collection_order: int = 0

@export_group("Appearance (placeholder primitives)")
@export var body_color: Color = Color(1.0, 0.8, 0.85)
@export var accent_color: Color = Color(1.0, 0.6, 0.7)
@export var body_scale: float = 1.0
## Wild creatures only: which primitive model WildCreature builds.
@export_enum("Round", "Sprout", "Longear", "Crest") var model_style: String = "Round"

@export_group("Stats")
@export var max_hunger: float = 100.0
@export var max_happiness: float = 100.0
@export var max_energy: float = 100.0

@export_group("Behavior")
@export var move_speed: float = 1.0
## Curious: pauses to look around. Playful: hops in bursts. Shy: leaves after a photo.
@export_enum("Curious", "Playful", "Shy") var personality: String = "Curious"
## Wild creatures: how far from their spawn point they wander.
@export var wander_radius: float = 2.5

@export_group("Photography")
## Multiplies the photo score. 1.0 = normal, 1.1 = a slightly more photogenic species.
@export var photo_modifier: float = 1.0

@export_group("Wild encounters")
## Chance (0 to 1) that a spawn attempt at a matching spawn point succeeds.
@export_range(0.0, 1.0) var spawn_chance: float = 1.0
## How long a wild creature stays before leaving, in seconds.
@export var stay_time_min: float = 45.0
@export var stay_time_max: float = 75.0

@export_group("Discovery")
## Extra coins for the FIRST photo of this species. Paid once.
@export var discovery_bonus: int = 20
