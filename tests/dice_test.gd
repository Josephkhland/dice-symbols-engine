extends Node2D


@export var dice: DiceResource

@onready var dice_pool_2d: DicePool2D = $DicePool2D


func _ready() -> void:
	if dice == null:
		push_error("Dice Test: No DiceResource assigned.")
		return

	# Create the runtime pool.
	var runtime_pool := DicePool.new()

	# Give the visual pool its runtime pool.
	dice_pool_2d.setup(runtime_pool)


func _on_button_pressed() -> void:
	roll_four_dice()


func roll_four_dice() -> void:
	if dice == null:
		return

	# Clear previous dice so each test is exactly four dice.
	dice_pool_2d.clear()

	var dice_array : Array[Dice]= [
		Dice.from_resource(dice),
		Dice.from_resource(dice),
		Dice.from_resource(dice),
		Dice.from_resource(dice)
	]

	dice_pool_2d.add_and_roll_dice(dice_array)


func _on_dice_pool_2d_dice_dragged_out(
	dice: Dice,
	side: DicePool2D.ExitSide
) -> void:

	print("Die dragged out: ", dice)
	print("Exit side: ", side)
