class_name DicePool3D
extends Node3D


signal dice_added(dice: Dice)
signal dice_removed(dice: Dice)

signal dice_rolled(dice: Dice, result: DiceRollResult)
signal rolled


enum LayoutMode {
	SCATTER,
	GRID
}


# -------------------------------------------------------------------
# Dice Layout
# -------------------------------------------------------------------

@export_category("Dice Layout")

@export var layout_mode: LayoutMode = LayoutMode.GRID:
	set(value):
		layout_mode = value
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export_range(1, 20) var grid_columns: int = 3:
	set(value):
		grid_columns = maxi(value, 1)
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export var grid_spacing: float = 0.25:
	set(value):
		grid_spacing = maxf(value, 0.0)
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export var center_grid: bool = true:
	set(value):
		center_grid = value
		if is_inside_tree():
			_rearrange_dice()

# -------------------------------------------------------------------
# Pool Area
# -------------------------------------------------------------------

@export_category("Pool Area")

@export var pool_size: Vector2 = Vector2(4.0, 3.0):
	set(value):
		pool_size = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export var scatter_margin: float = 0.6


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var pool: DicePool

var _dice_visuals: Dictionary[Dice, Dice3D] = {}

# Tracks which dice are still awaiting a result for the current roll. A new
# roll supersedes the previous one, so stale signals are ignored.
var _pending_visual_rolls: Dictionary[Dice, bool] = {}


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return


# -------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------

func setup(runtime_pool: DicePool) -> void:
	if runtime_pool == null:
		push_error(
			"DicePool3D: Cannot setup with a null DicePool."
		)
		return

	_disconnect_pool()

	pool = runtime_pool

	_connect_pool()

	_rebuild_visuals()


func _connect_pool() -> void:
	if pool == null:
		return

	if not pool.dice_added.is_connected(_on_pool_dice_added):
		pool.dice_added.connect(_on_pool_dice_added)

	if not pool.dice_removed.is_connected(_on_pool_dice_removed):
		pool.dice_removed.connect(_on_pool_dice_removed)


func _disconnect_pool() -> void:
	if pool == null:
		return

	if pool.dice_added.is_connected(_on_pool_dice_added):
		pool.dice_added.disconnect(_on_pool_dice_added)

	if pool.dice_removed.is_connected(_on_pool_dice_removed):
		pool.dice_removed.disconnect(_on_pool_dice_removed)


func _rebuild_visuals() -> void:
	for dice_visual in _dice_visuals.values():
		if is_instance_valid(dice_visual):
			dice_visual.queue_free()

	_dice_visuals.clear()
	_pending_visual_rolls.clear()

	if pool == null:
		return

	for die in pool.dice:
		_create_dice_visual(die)


# -------------------------------------------------------------------
# Dice Management
# -------------------------------------------------------------------

func add_dice(die: Dice) -> bool:
	if pool == null:
		push_error(
			"DicePool3D: Cannot add Dice before setup()."
		)
		return false

	return pool.add_dice(die)


func remove_dice(die: Dice) -> bool:
	if pool == null:
		return false

	return pool.remove_dice(die)


func clear() -> void:
	if pool == null:
		return

	_pending_visual_rolls.clear()
	pool.clear()


func get_dice() -> Array[Dice]:
	if pool == null:
		return []

	return pool.dice


func get_dice_visual(die: Dice) -> Dice3D:
	return _dice_visuals.get(die)


func size() -> int:
	if pool == null:
		return 0

	return pool.size()


func is_empty() -> bool:
	if pool == null:
		return true

	return pool.is_empty()


# -------------------------------------------------------------------
# Dice Visuals
# -------------------------------------------------------------------

func _create_dice_visual(die: Dice) -> void:
	if die == null:
		return

	if _dice_visuals.has(die):
		return

	var dice_visual := DiceEngine.create_dice_3d_from_dice(die)

	if dice_visual == null:
		return

	add_child(dice_visual)

	dice_visual.rolled.connect(
		_on_dice_visual_rolled.bind(die)
	)

	_dice_visuals[die] = dice_visual

	_place_dice_inside_pool(dice_visual)


func _on_pool_dice_added(die: Dice) -> void:
	_create_dice_visual(die)

	dice_added.emit(die)


func _on_pool_dice_removed(die: Dice) -> void:
	var dice_visual := _dice_visuals.get(die)

	if dice_visual != null and is_instance_valid(dice_visual):
		dice_visual.queue_free()

	_dice_visuals.erase(die)
	_pending_visual_rolls.erase(die)

	dice_removed.emit(die)


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

# Rolls every die in the pool through physics: each visual is raised above
# its spot and thrown with a random spin. Once a die settles, the face on
# top becomes its result and dice_rolled is emitted; when every die has
# settled, rolled is emitted.
func roll() -> void:
	if pool == null:
		push_error(
			"DicePool3D: Cannot roll before setup()."
		)
		return

	if pool.is_empty():
		push_warning(
			"DicePool3D: Cannot roll an empty pool."
		)
		return

	_roll_dice_visuals(pool.dice.duplicate())


func roll_dice_multiple(
	dice_to_roll: Array[Dice]
) -> void:

	if pool == null:
		return

	var targets: Array[Dice] = []

	for die in dice_to_roll:
		if _dice_visuals.has(die):
			targets.append(die)

	if targets.is_empty():
		return

	_roll_dice_visuals(targets)


func add_and_roll_dice(
	dice_to_roll: Array[Dice]
) -> void:

	pool.add_dice_multiple(dice_to_roll)

	roll_dice_multiple(dice_to_roll)


func _roll_dice_visuals(dice_to_roll: Array[Dice]) -> void:
	# A new roll supersedes any previous in-flight roll: drop the pending
	# account so stale results from the old throw are ignored.
	_pending_visual_rolls.clear()

	for die in dice_to_roll:
		var dice_visual := _dice_visuals.get(die)

		if dice_visual == null:
			continue

		_pending_visual_rolls[die] = true
		_launch_dice(dice_visual)

	_evaluate_roll_complete()


func _launch_dice(dice_visual: Dice3D) -> void:
	if dice_visual == null:
		return

	# Start from the die's rest spot; the dice_visual.roll() throw does the
	# rest of the work (horizontal toss + end-over-end tumble).
	var rest_position := _compute_rest_position(dice_visual)

	dice_visual.global_transform = Transform3D(
		Basis.IDENTITY,
		rest_position
	)

	dice_visual.linear_velocity = Vector3.ZERO
	dice_visual.angular_velocity = Vector3.ZERO
	dice_visual.sleeping = false

	# Defer the throw so the physics space registers this body before its
	# initial velocities are applied (a same-frame add+launch would have the
	# body inserted and its velocities reset before it ever moves).
	dice_visual.roll.call_deferred()


func _on_dice_visual_rolled(
	result: DiceRollResult,
	die: Dice
) -> void:

	# Ignore stale/duplicate results (die already completed, was cleared,
	# or belongs to a roll that has been superseded).
	if not _pending_visual_rolls.has(die):
		return

	if not _pending_visual_rolls[die]:
		return

	_pending_visual_rolls[die] = false

	dice_rolled.emit(
		die,
		result
	)

	_evaluate_roll_complete()


func _evaluate_roll_complete() -> void:
	for pending in _pending_visual_rolls.values():
		if pending:
			return

	_pending_visual_rolls.clear()
	rolled.emit()


# -------------------------------------------------------------------
# Results
# -------------------------------------------------------------------

func get_results() -> Array[DiceRollResult]:
	if pool == null:
		return []

	return pool.get_results()


func get_symbols() -> Array[DiceSymbolResource]:
	if pool == null:
		return []

	return pool.get_symbols()


# -------------------------------------------------------------------
# Layout
# -------------------------------------------------------------------

func _rearrange_dice() -> void:
	if pool == null:
		return

	for die in pool.dice:
		var dice_visual := _dice_visuals.get(die)

		if dice_visual == null:
			continue

		_place_dice_inside_pool(dice_visual)


func _get_visual_radius(dice_visual: Dice3D) -> float:
	if dice_visual == null:
		return 0.5

	return dice_visual.dice_size / 2.0


func _place_dice_inside_pool(dice_visual: Dice3D) -> void:
	if dice_visual == null:
		return

	var rest_position := _compute_rest_position(dice_visual)

	dice_visual.global_transform = Transform3D(
		Basis.IDENTITY,
		rest_position
	)

	dice_visual.linear_velocity = Vector3.ZERO
	dice_visual.angular_velocity = Vector3.ZERO
	dice_visual.sleeping = false


func _compute_rest_position(dice_visual: Dice3D) -> Vector3:
	if dice_visual == null:
		return Vector3.ZERO

	match layout_mode:
		LayoutMode.SCATTER:
			return _compute_scatter_position(dice_visual)

		LayoutMode.GRID:
			return _compute_grid_position(dice_visual)

	return Vector3.ZERO


func _compute_scatter_position(dice_visual: Dice3D) -> Vector3:
	var radius := _get_visual_radius(dice_visual)

	var min_x := -pool_size.x / 2.0 + radius + scatter_margin
	var max_x := pool_size.x / 2.0 - radius - scatter_margin

	var min_z := -pool_size.y / 2.0 + radius + scatter_margin
	var max_z := pool_size.y / 2.0 - radius - scatter_margin

	var x := 0.0

	if min_x < max_x:
		x = randf_range(min_x, max_x)

	var z := 0.0

	if min_z < max_z:
		z = randf_range(min_z, max_z)

	return Vector3(
		x,
		dice_visual.dice_size / 2.0,
		z
	)


func _compute_grid_position(dice_visual: Dice3D) -> Vector3:
	var die := dice_visual.dice

	if pool == null or die == null:
		return Vector3.ZERO

	var dice_count := _dice_visuals.size()

	var index := pool.dice.find(die)

	var columns := maxi(grid_columns, 1)
	var rows := ceili(float(dice_count) / float(columns))

	var dice_size := dice_visual.dice_size
	var step := dice_size + grid_spacing

	var total_width : float = (
		min(columns, dice_count) * step
		- grid_spacing
	)

	var total_height := (
		rows * step
		- grid_spacing
	)

	var start_position: Vector3

	if center_grid:
		start_position = Vector3(
			-total_width / 2.0,
			0.0,
			-total_height / 2.0
		)
	else:
		start_position = Vector3(
			-dice_size / 2.0,
			0.0,
			-dice_size / 2.0
		)

	var column := index % columns
	var row := index / columns

	return Vector3(
		start_position.x + column * step + dice_size / 2.0,
		dice_size / 2.0,
		start_position.z + row * step + dice_size / 2.0
	)