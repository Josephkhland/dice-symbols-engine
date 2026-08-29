@tool
class_name DicePool2D
extends Node2D


signal dice_added(dice: Dice)
signal dice_removed(dice: Dice)

signal dice_selected(dice: Dice)
signal dice_deselected(dice: Dice)

signal dice_drag_started(dice: Dice)
signal dice_dragged(dice: Dice, position: Vector2)
signal dice_dragged_out(dice: Dice, side: ExitSide)

signal dice_rolled(dice: Dice, result: DiceRollResult)
signal rolled


enum ExitSide {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT
}

enum LayoutMode {
	SCATTER,
	GRID
}

@export_category("Dice Layout")
@export var layout_mode: LayoutMode = LayoutMode.SCATTER:
	set(value):
		layout_mode = value
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export_range(1, 20) var grid_columns: int = 3:
	set(value):
		grid_columns = maxi(value, 1)
		if is_inside_tree() and not Engine.is_editor_hint():
			_rearrange_dice()

@export var grid_spacing: Vector2 = Vector2(16.0, 16.0)
@export var center_grid: bool = true:
	set(value):
		center_grid = value
		if is_inside_tree():
			_rearrange_dice()

# -------------------------------------------------------------------
# Pool Area
# -------------------------------------------------------------------

@export_category("Pool Area")

@export var pool_size: Vector2 = Vector2(600.0, 300.0):
	set(value):
		pool_size = value
		queue_redraw()

@export var pool_offset: Vector2 = Vector2.ZERO:
	set(value):
		pool_offset = value
		queue_redraw()

@export var draw_pool_area: bool = true:
	set(value):
		draw_pool_area = value
		queue_redraw()

@export var pool_area_color: Color = Color(1.0, 1.0, 1.0, 0.08):
	set(value):
		pool_area_color = value
		queue_redraw()

@export var pool_border_color: Color = Color.WHITE:
	set(value):
		pool_border_color = value
		queue_redraw()

@export var pool_border_width: float = 2.0:
	set(value):
		pool_border_width = value
		queue_redraw()

var _drag_start_positions: Dictionary[Dice, Vector2] = {}

# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

@export_category("Rolling")

@export var scatter_margin: float = 16.0
@export var random_rotation: float = TAU


# -------------------------------------------------------------------
# Interaction
# -------------------------------------------------------------------

@export_category("Interaction")

@export var selectable: bool = true
@export var draggable: bool = false
@export var multi_select: bool = false


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var pool: DicePool

var _dice_visuals: Dictionary[Dice, Dice2D] = {}
var _selected_dice: Array[Dice] = []

var _pending_visual_rolls: int = 0

var _dragged_die: Dice = null
var _dragged_visual: Dice2D = null
var _drag_offset: Vector2 = Vector2.ZERO


# -------------------------------------------------------------------
# Pool Area
# -------------------------------------------------------------------

func get_pool_rect() -> Rect2:
	return Rect2(
		pool_offset - pool_size / 2.0,
		pool_size
	)


func _draw() -> void:
	if not draw_pool_area:
		return

	var rect := get_pool_rect()

	draw_rect(
		rect,
		pool_area_color,
		true
	)

	draw_rect(
		rect,
		pool_border_color,
		false,
		pool_border_width
	)


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	queue_redraw()

	if Engine.is_editor_hint():
		return


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if _dragged_die == null:
		return

	if event is InputEventMouseMotion:
		_update_drag_position()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_finish_drag()


# -------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------

func setup(runtime_pool: DicePool) -> void:
	if runtime_pool == null:
		push_error(
			"DicePool2D: Cannot setup with a null DicePool."
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

	if not pool.dice_rolled.is_connected(_on_pool_dice_rolled):
		pool.dice_rolled.connect(_on_pool_dice_rolled)


func _disconnect_pool() -> void:
	if pool == null:
		return

	if pool.dice_added.is_connected(_on_pool_dice_added):
		pool.dice_added.disconnect(_on_pool_dice_added)

	if pool.dice_removed.is_connected(_on_pool_dice_removed):
		pool.dice_removed.disconnect(_on_pool_dice_removed)

	if pool.dice_rolled.is_connected(_on_pool_dice_rolled):
		pool.dice_rolled.disconnect(_on_pool_dice_rolled)


func _rebuild_visuals() -> void:
	for dice_visual in _dice_visuals.values():
		if is_instance_valid(dice_visual):
			dice_visual.queue_free()

	_dice_visuals.clear()
	_selected_dice.clear()

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
			"DicePool2D: Cannot add Dice before setup()."
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

	pool.clear()


func get_dice() -> Array[Dice]:
	if pool == null:
		return []

	return pool.dice


func get_dice_visual(die: Dice) -> Dice2D:
	return _dice_visuals.get(die)


func get_selected_dice() -> Array[Dice]:
	return _selected_dice.duplicate()


# -------------------------------------------------------------------
# Dice Visuals
# -------------------------------------------------------------------

func _create_dice_visual(die: Dice) -> void:
	if die == null:
		return

	if _dice_visuals.has(die):
		return

	var dice_visual := DiceEngine.create_dice_2d_from_dice(die)

	if dice_visual == null:
		return

	add_child(dice_visual)

	_dice_visuals[die] = dice_visual

	# Dice2D tells us when the player presses it.
	dice_visual.pointer_pressed.connect(
		_on_dice_pointer_pressed.bind(die)
	)

	dice_visual.pointer_released.connect(
		_on_dice_pointer_released.bind(die)
	)

	dice_visual.rolled.connect(
		_on_dice_visual_rolled.bind(die)
	)

	_rearrange_dice()


func _on_pool_dice_added(die: Dice) -> void:
	_create_dice_visual(die)

	dice_added.emit(die)


func _on_pool_dice_removed(die: Dice) -> void:
	var dice_visual := _dice_visuals.get(die)

	if dice_visual != null and is_instance_valid(dice_visual):
		dice_visual.queue_free()

	_dice_visuals.erase(die)

	_deselect_dice(die)

	if _dragged_die == die:
		_dragged_die = null
		_dragged_visual = null
		_drag_offset = Vector2.ZERO

	dice_removed.emit(die)


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------
func roll() -> void:
	if pool == null:
		push_error(
			"DicePool2D: Cannot roll before setup()."
		)
		return

	if pool.is_empty():
		push_warning(
			"DicePool2D: Cannot roll an empty pool."
		)
		return

	if _pending_visual_rolls > 0:
		return

	pool.roll()

func add_and_roll_dice(
	dice_to_roll: Array[Dice]
) -> void:

	pool.add_dice_multiple(dice_to_roll)

	pool.roll_dice_multiple(dice_to_roll)

func roll_dice_multiple(
	dice_to_roll: Array[Dice]
) -> void:

	if pool == null:
		return

	if _pending_visual_rolls > 0:
		return

	pool.roll_dice_multiple(dice_to_roll)

func _scatter_dice(dice_visual: Dice2D) -> void:
	dice_visual.position = _get_random_position_for_dice(
		dice_visual
	)

	dice_visual.rotation = randf_range(
		-random_rotation,
		random_rotation
	)


func _get_random_position_for_dice(
	dice_visual: Dice2D
) -> Vector2:

	var rect := get_pool_rect()

	var half_size := dice_visual.dice_size / 2.0

	var min_x := (
		rect.position.x
		+ half_size.x
		+ scatter_margin
	)

	var max_x := (
		rect.end.x
		- half_size.x
		- scatter_margin
	)

	var min_y := (
		rect.position.y
		+ half_size.y
		+ scatter_margin
	)

	var max_y := (
		rect.end.y
		- half_size.y
		- scatter_margin
	)

	if min_x > max_x:
		min_x = rect.get_center().x
		max_x = min_x

	if min_y > max_y:
		min_y = rect.get_center().y
		max_y = min_y

	return Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)


func _place_dice_inside_pool(
	dice_visual: Dice2D
) -> void:

	dice_visual.position = _get_random_position_for_dice(
		dice_visual
	)

	dice_visual.rotation = randf_range(
		-random_rotation,
		random_rotation
	)


func _on_dice_visual_rolled(
	result: DiceRollResult,
	die: Dice
) -> void:

	dice_rolled.emit(
		die,
		result
	)

	_visual_roll_finished()


func _visual_roll_finished() -> void:
	_pending_visual_rolls -= 1

	if _pending_visual_rolls > 0:
		return

	_pending_visual_rolls = 0

	rolled.emit()


func _on_pool_dice_rolled(
	die: Dice,
	result: DiceRollResult
) -> void:

	var dice_visual := _dice_visuals.get(die)

	if dice_visual == null:
		return

	_pending_visual_rolls += 1

	if layout_mode == LayoutMode.SCATTER:
		_scatter_dice(dice_visual)
	else:
		_rearrange_dice()

	dice_visual.roll_result(result)


# -------------------------------------------------------------------
# Selection
# -------------------------------------------------------------------

func select_dice(die: Dice) -> void:
	if not selectable:
		return

	if die == null:
		return

	if not _dice_visuals.has(die):
		return

	if _selected_dice.has(die):
		return

	if not multi_select:
		clear_selection()

	_selected_dice.append(die)

	dice_selected.emit(die)


func deselect_dice(die: Dice) -> void:
	_deselect_dice(die)


func _deselect_dice(die: Dice) -> void:
	if not _selected_dice.has(die):
		return

	_selected_dice.erase(die)

	dice_deselected.emit(die)


func clear_selection() -> void:
	var previous_selection := _selected_dice.duplicate()

	_selected_dice.clear()

	for die in previous_selection:
		dice_deselected.emit(die)


# -------------------------------------------------------------------
# Dragging / Exit Detection
# -------------------------------------------------------------------

func _is_die_outside(
	dice_visual: Dice2D
) -> bool:

	if dice_visual == null:
		return false

	var rect := get_pool_rect()

	var die_position := to_local(
		dice_visual.global_position
	)

	var half_size := dice_visual.dice_size / 2.0

	var die_rect := Rect2(
		die_position - half_size,
		dice_visual.dice_size
	)

	return not rect.encloses(die_rect)


func _get_exit_side_for_dice(
	dice_visual: Dice2D
) -> int:

	var rect := get_pool_rect()

	var die_position := to_local(
		dice_visual.global_position
	)

	var half_size := dice_visual.dice_size / 2.0

	var die_rect := Rect2(
		die_position - half_size,
		dice_visual.dice_size
	)

	if die_rect.position.y < rect.position.y:
		return ExitSide.TOP

	if die_rect.end.x > rect.end.x:
		return ExitSide.RIGHT

	if die_rect.end.y > rect.end.y:
		return ExitSide.BOTTOM

	if die_rect.position.x < rect.position.x:
		return ExitSide.LEFT

	return -1

func _on_dice_pointer_pressed(die: Dice) -> void:
	if not draggable:
		return

	var dice_visual := _dice_visuals.get(die)

	if dice_visual == null:
		return

	_dragged_die = die
	_dragged_visual = dice_visual

	_drag_offset = (
		dice_visual.global_position
		- get_global_mouse_position()
	)

	_drag_start_positions[die] = dice_visual.position

	dice_drag_started.emit(die)

func _on_dice_pointer_released(die: Dice) -> void:
	if _dragged_die != die:
		return

	_finish_drag()

func _update_drag_position() -> void:
	if _dragged_visual == null:
		return

	var mouse_position := get_global_mouse_position()

	var new_position := (
		mouse_position
		+ _drag_offset
	)

	_dragged_visual.global_position = new_position

	dice_dragged.emit(
		_dragged_die,
		new_position
	)

func _finish_drag() -> void:
	if _dragged_die == null:
		return

	var die := _dragged_die
	var dice_visual := _dragged_visual

	if dice_visual != null and _is_die_outside(dice_visual):
		var side := _get_exit_side_for_dice(dice_visual)

		if side != -1:
			# Put the die back where the drag started.
			if _drag_start_positions.has(die):
				dice_visual.position = _drag_start_positions[die]

			dice_dragged_out.emit(die, side)

	_drag_start_positions.erase(die)

	_dragged_die = null
	_dragged_visual = null
	_drag_offset = Vector2.ZERO

func _rearrange_dice() -> void:
	if pool == null:
		return

	match layout_mode:
		LayoutMode.SCATTER:
			_arrange_scattered()

		LayoutMode.GRID:
			_arrange_grid()

func _arrange_scattered() -> void:
	for die in pool.dice:
		var dice_visual := _dice_visuals.get(die)

		if dice_visual == null:
			continue

		_place_dice_inside_pool(dice_visual)

func _arrange_grid() -> void:
	var dice_count := _dice_visuals.size()

	if dice_count == 0:
		return

	var columns := maxi(grid_columns, 1)
	var rows := ceili(float(dice_count) / float(columns))

	var dice_array: Array[Dice] = _dice_visuals.keys()

	var dice_size := Vector2.ZERO

	if dice_array.size() > 0:
		var first_visual := _dice_visuals[dice_array[0]]

		if first_visual != null:
			dice_size = first_visual.dice_size

	var spacing := dice_size + grid_spacing

	var total_width : float = (
		min(columns, dice_count) * spacing.x
		- grid_spacing.x
	)

	var total_height := (
		rows * spacing.y
		- grid_spacing.y
	)

	var rect := get_pool_rect()

	var start_position: Vector2

	if center_grid:
		start_position = (
			rect.get_center()
			- Vector2(total_width, total_height) / 2.0
			+ dice_size / 2.0
		)
	else:
		start_position = (
			rect.position
			+ Vector2(
				scatter_margin + dice_size.x / 2.0,
				scatter_margin + dice_size.y / 2.0
			)
		)

	for i in dice_array.size():
		var die := dice_array[i]
		var dice_visual := _dice_visuals.get(die)

		if dice_visual == null:
			continue

		var column := i % columns
		var row := i / columns

		dice_visual.position = start_position + Vector2(
			column * spacing.x,
			row * spacing.y
		)

		dice_visual.rotation = 0.0
