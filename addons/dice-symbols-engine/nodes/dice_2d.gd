class_name Dice2D
extends Node2D


signal pointer_pressed
signal pointer_released
signal rolled(result: DiceRollResult)


@export_category("Appearance")
@export var background_color: Color = Color.WHITE
@export var background_texture: Texture2D
@export var dice_size: Vector2 = Vector2(128.0, 128.0)


@export_category("Border")
@export var border_color: Color = Color.BLACK
@export_range(0.0, 20.0) var border_width: float = 4.0


@export_category("Roll Animation")
@export var roll_duration: float = 0.8
@export var face_changes: int = 10
@export var final_pause: float = 0.08
@export var flash_duration: float = 0.12


var dice: Dice
var visual_definition: StandardDiceVisualResource

var visual: Node2D
var background: Polygon2D
var border: Line2D
var face_2d: DiceFace2D
var input_area: Area2D

var is_rolling: bool = false


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	_ensure_visual()


# -------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------

func setup(runtime_dice: Dice) -> void:
	if runtime_dice == null:
		push_error(
			"Dice2D: Cannot setup with a null Dice."
		)
		return

	if runtime_dice.faces.is_empty():
		push_error(
			"Dice2D: Cannot setup a Dice with no faces."
		)
		return

	# Important:
	# Dice2D may be setup before it is added to the scene tree.
	_ensure_visual()

	dice = runtime_dice

	face_2d.face_size = dice_size

	if not _prepare_visual_definition():
		return

	_display_face(dice.faces[0])


func _ensure_visual() -> void:
	if visual != null:
		return

	_create_visual()


# -------------------------------------------------------------------
# Visual Definition
# -------------------------------------------------------------------

func _prepare_visual_definition() -> bool:
	if dice == null:
		return false

	var side_count := dice.faces.size()
	var max_symbol_count := _get_max_symbol_count()

	visual_definition = DiceVisualLibrary.get_standard_dice(
		side_count
	)

	if visual_definition == null:
		push_error(
			"Dice2D: No standard visual found for a D%d."
			% side_count
		)
		return false

	var supported_symbol_count := (
		_get_max_layout_symbol_count()
	)

	if supported_symbol_count < max_symbol_count:
		push_error(
			"Dice2D: Standard D%d visual supports up to %d symbols, "
			+ "but this die requires %d."
			% [
				side_count,
				supported_symbol_count,
				max_symbol_count
			]
		)

		visual_definition = null

		return false

	return true


func _get_max_layout_symbol_count() -> int:
	if visual_definition == null:
		return 0

	var result := 0

	for layout in visual_definition.layouts:
		if layout == null:
			continue

		result = maxi(
			result,
			layout.entries.size()
		)

	return result


func _get_max_symbol_count() -> int:
	if dice == null:
		return 0

	var result := 0

	for face in dice.faces:
		if face == null:
			continue

		result = maxi(
			result,
			face.symbols.size()
		)

	return result


func _get_layout_for_face(
	face: DiceFace
) -> DiceFaceLayoutResource:

	if face == null:
		return null

	if visual_definition == null:
		return null

	var symbol_count := face.symbols.size()

	for layout in visual_definition.layouts:
		if layout == null:
			continue

		if layout.entries.size() == symbol_count:
			return layout

	return null


# -------------------------------------------------------------------
# Face Display
# -------------------------------------------------------------------

func _display_face(face: DiceFace) -> void:
	if face == null:
		push_error(
			"Dice2D: Cannot display a null face."
		)
		return

	var layout := _get_layout_for_face(face)

	if layout == null:
		push_error(
			"Dice2D: No layout found for a face with %d symbols."
			% face.symbols.size()
		)
		return

	face_2d.setup(face, layout)


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

func roll() -> void:
	if is_rolling:
		return

	if dice == null:
		push_error(
			"Dice2D: Cannot roll before setup() has been called."
		)
		return

	var result := dice.roll()

	await roll_result(result)


func roll_result(result: DiceRollResult) -> void:
	if is_rolling:
		return

	if result == null:
		push_error(
			"Dice2D: Cannot animate a null result."
		)
		return

	is_rolling = true

	await _play_roll_animation(result)

	is_rolling = false

	rolled.emit(result)


func get_result() -> DiceRollResult:
	if dice == null:
		return null

	return dice.get_last_result()


# -------------------------------------------------------------------
# Visual Creation
# -------------------------------------------------------------------

func _create_visual() -> void:
	if visual != null:
		return

	visual = Node2D.new()
	visual.name = "Visual"

	add_child(visual)

	_create_background()
	_create_border()

	face_2d = DiceFace2D.new()
	face_2d.name = "DiceFace2D"
	face_2d.face_size = dice_size

	visual.add_child(face_2d)

	_create_input_area()


func _create_background() -> void:
	background = Polygon2D.new()
	background.name = "Background"

	var half_size := dice_size / 2.0

	background.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])

	background.color = background_color
	background.texture = background_texture

	visual.add_child(background)


func _create_border() -> void:
	border = Line2D.new()
	border.name = "Border"

	var half_size := dice_size / 2.0

	border.points = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])

	border.closed = true
	border.width = border_width
	border.default_color = border_color

	visual.add_child(border)

func _create_input_area() -> void:
	if Engine.is_editor_hint():
		return

	if input_area != null:
		return

	input_area = Area2D.new()
	input_area.name = "InputArea"

	# Allow the Area2D to receive mouse input.
	input_area.input_pickable = true
	input_area.monitoring = false
	input_area.monitorable = false

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape"

	var shape := RectangleShape2D.new()
	shape.size = dice_size

	collision.shape = shape

	input_area.add_child(collision)
	visual.add_child(input_area)

	# Connect the Area2D's actual input event to our handler.
	input_area.input_event.connect(_on_input_event)


# -------------------------------------------------------------------
# Roll Animation
# -------------------------------------------------------------------
func _play_roll_animation(
	result: DiceRollResult
) -> void:

	var tween := create_tween()

	var original_border_color := border.default_color

	# ---------------------------------------------------------------
	# Cycle through random faces
	# ---------------------------------------------------------------

	for i in face_changes:
		var progress := float(i) / float(face_changes)

		# Start fast and gradually slow down.
		var interval := lerp(
			0.035,
			0.12,
			progress * progress
		)

		var random_face := dice.faces.pick_random()

		tween.tween_callback(
			_display_face.bind(random_face)
		)

		tween.tween_interval(interval)

	# ---------------------------------------------------------------
	# Lock final result
	# ---------------------------------------------------------------

	tween.tween_callback(
		_display_face.bind(result.face)
	)

	tween.tween_interval(final_pause)

	# ---------------------------------------------------------------
	# Flash border
	# ---------------------------------------------------------------

	tween.tween_property(
		border,
		"default_color",
		Color.WHITE,
		flash_duration * 0.25
	)

	tween.tween_property(
		border,
		"default_color",
		original_border_color,
		flash_duration * 0.75
	)

	await tween.finished
# -------------------------------------------------------------------
# Standalone Pointer Input
# -------------------------------------------------------------------

func _on_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:

	if event is not InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		pointer_pressed.emit()
	else:
		pointer_released.emit()
