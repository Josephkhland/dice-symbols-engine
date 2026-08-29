class_name DiceVisualLibrary
extends RefCounted


static var _standard_dice := {
	#4: preload("res://addons/dice-symbols-engine/library/standard_dice/d4.tres"),
	6: preload("res://addons/dice-symbols-engine/library/standard_dice/d6.tres"),
	#8: preload("res://addons/dice-symbols-engine/library/standard_dice/d8.tres"),
	#10: preload("res://addons/dice-symbols-engine/library/standard_dice/d10.tres"),
	#12: preload("res://addons/dice-symbols-engine/library/standard_dice/d12.tres"),
	#20: preload("res://addons/dice-symbols-engine/library/standard_dice/d20.tres"),
}


static func get_standard_dice(
	side_count: int
) -> StandardDiceVisualResource:

	return _standard_dice.get(side_count)
