class_name PhotoScoring
extends RefCounted

## The photo score formula. Every number you may want to tune is a constant
## here. Maximum points add up to 100:
##   visibility 10 + size 35 + composition 25 + pose 20 + mood 5 + bond 5

const MAX_VISIBILITY := 10.0
const MAX_SIZE := 35.0
const MAX_COMPOSITION := 25.0
const MAX_POSE := 20.0
const MAX_MOOD := 5.0
const MAX_BOND := 5.0

## Size = creature height / camera.size (fraction of the screen height).
## 0 points at ZERO_SMALL, full points between FULL_FROM and FULL_TO,
## 0 points again at ZERO_BIG (too close).
const SIZE_ZERO_SMALL := 0.05
const SIZE_FULL_FROM := 0.30
const SIZE_FULL_TO := 0.60
const SIZE_ZERO_BIG := 1.10

## Distance from the screen center (in half-screen-heights) that gives 0 composition points.
const CENTER_FALLOFF := 0.8

const COINS_PER_POINT := 0.3
const RARITY_COIN_MULTIPLIER := {"Common": 1.0, "Uncommon": 1.25, "Rare": 1.6}

## [minimum score, text], checked from the top.
const RATINGS := [
	[90, "Masterpiece! Frame-worthy!"],
	[75, "Great shot!"],
	[55, "Nice photo."],
	[35, "Not bad, but you can do better."],
	[0, "A bit blurry... try getting closer."],
]


## Returns {score, coins, rating, breakdown}. "breakdown" is an Array of
## {label, points, max} rows that the result panel displays.
static func evaluate(
	visible_fraction: float,
	size_fraction: float,
	center_offset: float,
	pose_value: float,
	happiness_ratio: float,
	bond_level: int,
	species: CreatureSpecies
) -> Dictionary:
	var visibility_pts := MAX_VISIBILITY * clampf(visible_fraction, 0.0, 1.0)
	var size_pts := MAX_SIZE * _trapezoid(size_fraction, SIZE_ZERO_SMALL, SIZE_FULL_FROM, SIZE_FULL_TO, SIZE_ZERO_BIG)
	var composition_pts := MAX_COMPOSITION * (1.0 - clampf(center_offset / CENTER_FALLOFF, 0.0, 1.0))
	var pose_pts := MAX_POSE * clampf(pose_value, 0.0, 1.0)
	var mood_pts := MAX_MOOD * clampf(happiness_ratio, 0.0, 1.0)
	var bond_pts := MAX_BOND * float(bond_level - 1) / float(CreatureStats.MAX_BOND_LEVEL - 1)

	var subtotal := visibility_pts + size_pts + composition_pts + pose_pts + mood_pts + bond_pts
	var score := clampi(roundi(subtotal * species.photo_modifier), 0, 100)
	var rarity_multiplier: float = RARITY_COIN_MULTIPLIER.get(species.rarity, 1.0)
	var coins := maxi(1, roundi(score * COINS_PER_POINT * rarity_multiplier))

	return {
		"score": score,
		"coins": coins,
		"rating": get_rating(score),
		"breakdown": [
			_row("Visibility", visibility_pts, MAX_VISIBILITY),
			_row("Size in frame", size_pts, MAX_SIZE),
			_row("Composition", composition_pts, MAX_COMPOSITION),
			_row("Pose", pose_pts, MAX_POSE),
			_row("Happy subject", mood_pts, MAX_MOOD),
			_row("Bond", bond_pts, MAX_BOND),
		],
	}


static func get_rating(score: int) -> String:
	for entry in RATINGS:
		if score >= int(entry[0]):
			return str(entry[1])
	return ""


static func _row(label: String, points: float, max_points: float) -> Dictionary:
	return {"label": label, "points": points, "max": max_points}


## 0 below zero_lo, rises to 1 at full_lo, stays 1 until full_hi, falls to 0 at zero_hi.
static func _trapezoid(value: float, zero_lo: float, full_lo: float, full_hi: float, zero_hi: float) -> float:
	if value <= zero_lo or value >= zero_hi:
		return 0.0
	if value < full_lo:
		return (value - zero_lo) / (full_lo - zero_lo)
	if value > full_hi:
		return (zero_hi - value) / (zero_hi - full_hi)
	return 1.0
