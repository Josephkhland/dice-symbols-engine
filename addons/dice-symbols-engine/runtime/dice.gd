class_name Dice
extends RefCounted

var faces: Array[DiceFace]
var last_result : DiceRollResult


static func from_resource(resource: DiceResource) -> Dice:
	var dice := Dice.new()

	for i in resource.faces.size():
		var face := DiceFace.from_resource(
			resource.faces[i]
		)

		dice.faces.append(face)

	return dice


func roll() -> DiceRollResult:
	if faces.is_empty():
		push_error("Cannot roll a dice with no faces.")
		return null

	var face := faces.pick_random()
	last_result = DiceRollResult.new(face)

	return last_result


func get_last_result() -> DiceRollResult:
	return last_result
