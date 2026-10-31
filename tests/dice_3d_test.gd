extends Control


@export var dice: DiceResource

@export var dice_to_roll: int = 5

@onready var dice_pool_3d_view: DicePool3DView = $MarginContainer/VBoxContainer/AspectBox/DicePool3DView
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultsScroll/ResultLabel


func _ready() -> void:
	if dice == null:
		push_error("Dice3D Test: No DiceResource assigned.")
		return

	var runtime_pool := DicePool.new()

	dice_pool_3d_view.setup(runtime_pool)


func _on_roll_button_pressed() -> void:
	roll_dice()


func roll_dice() -> void:
	if dice == null:
		return

	dice_pool_3d_view.clear()

	var dice_array: Array[Dice] = []

	for i in maxi(dice_to_roll, 1):
		dice_array.append(Dice.from_resource(dice))

	dice_pool_3d_view.add_and_roll_dice(dice_array)


func _update_result_label() -> void:
	var symbols := dice_pool_3d_view.get_symbols()

	var text := "RESULTS\n"

	for symbol in symbols:
		text += "- %s\n" % symbol.name

	result_label.text = text


func _on_dice_pool_3d_view_dice_rolled(
	die: Dice,
	result: DiceRollResult
) -> void:

	if result == null or result.face == null:
		return

	var names: Array[String] = []

	for symbol in result.face.symbols:
		names.append(String(symbol.name))

	print("Die: ", die, " -> symbols: ", ", ".join(names))


func _on_dice_pool_3d_view_rolled() -> void:
	_update_result_label()
