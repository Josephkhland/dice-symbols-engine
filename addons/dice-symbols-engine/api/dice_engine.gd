class_name DiceEngine
extends RefCounted


const DICE_2D_SCENE := preload(
	"res://addons/dice-symbols-engine/nodes/dice_2d.tscn"
)


static func create_dice(
	dice_resource: DiceResource
) -> Dice:
	if dice_resource == null:
		push_error(
			"DiceEngine: Cannot create Dice from a null DiceResource."
		)
		return null

	return Dice.from_resource(dice_resource)


static func create_dice_2d(
	dice_resource: DiceResource
) -> Dice2D:
	if dice_resource == null:
		push_error(
			"DiceEngine: Cannot create Dice2D from a null DiceResource."
		)
		return null

	var dice := create_dice(dice_resource)

	if dice == null:
		return null

	return create_dice_2d_from_dice(dice)


static func create_dice_2d_from_dice(
	dice: Dice
) -> Dice2D:
	if dice == null:
		push_error(
			"DiceEngine: Cannot create Dice2D from a null Dice."
		)
		return null

	var dice_2d := DICE_2D_SCENE.instantiate() as Dice2D

	if dice_2d == null:
		push_error(
			"DiceEngine: Failed to instantiate Dice2D."
		)
		return null

	dice_2d.setup(dice)

	return dice_2d
