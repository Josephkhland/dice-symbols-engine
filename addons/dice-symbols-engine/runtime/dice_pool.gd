class_name DicePool
extends RefCounted


signal dice_added(dice: Dice)
signal dice_removed(dice: Dice)

signal dice_rolled(
	dice: Dice,
	result: DiceRollResult
)

signal rolled


var dice: Array[Dice] = []


# -------------------------------------------------------------------
# Dice Management
# -------------------------------------------------------------------

func add_dice(die: Dice) -> bool:
	if die == null:
		push_error("DicePool: Cannot add a null Dice.")
		return false

	if dice.has(die):
		push_warning("DicePool: Dice is already part of this pool.")
		return false

	dice.append(die)

	dice_added.emit(die)

	return true

func add_dice_multiple(
	dice_to_add: Array[Dice]
) -> void:

	for die in dice_to_add:
		add_dice(die)

func remove_dice(die: Dice) -> bool:
	if die == null:
		return false

	var index := dice.find(die)

	if index == -1:
		return false

	dice.remove_at(index)

	dice_removed.emit(die)

	return true


func remove_dice_at(index: int) -> Dice:
	if index < 0 or index >= dice.size():
		return null

	var die := dice[index]

	dice.remove_at(index)

	dice_removed.emit(die)

	return die


func clear() -> void:
	var removed_dice := dice.duplicate()

	dice.clear()

	for die in removed_dice:
		dice_removed.emit(die)


func size() -> int:
	return dice.size()


func is_empty() -> bool:
	return dice.is_empty()


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

func roll() -> void:
	if dice.is_empty():
		push_warning("DicePool: Cannot roll an empty pool.")
		return

	for die in dice:
		_roll_die(die)

	rolled.emit()


func roll_dice(die: Dice) -> bool:
	if die == null:
		return false

	if not dice.has(die):
		push_warning(
			"DicePool: Cannot roll a Dice that is not part of the pool."
		)
		return false

	_roll_die(die)

	return true

func roll_dice_multiple(
	dice_to_roll: Array[Dice]
) -> void:

	var rolled_any := false

	for die in dice_to_roll:
		if die == null:
			continue

		if not dice.has(die):
			push_warning(
				"DicePool: Cannot roll a Dice that is not part of the pool."
			)
			continue

		_roll_die(die)
		rolled_any = true

	if rolled_any:
		rolled.emit()

func roll_dice_at(index: int) -> bool:
	if index < 0 or index >= dice.size():
		return false

	_roll_die(dice[index])

	return true


func _roll_die(die: Dice) -> void:
	var result := die.roll()

	dice_rolled.emit(
		die,
		result
	)


# -------------------------------------------------------------------
# Results
# -------------------------------------------------------------------

func get_results() -> Array[DiceRollResult]:
	var results: Array[DiceRollResult] = []

	for die in dice:
		var result := die.get_last_result()

		if result != null:
			results.append(result)

	return results


func get_symbols() -> Array[DiceSymbolResource]:
	var symbols: Array[DiceSymbolResource] = []

	for result in get_results():
		if result.face == null:
			continue

		symbols.append_array(result.face.symbols)

	return symbols
