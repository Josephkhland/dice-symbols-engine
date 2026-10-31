class_name Dice3D
extends RigidBody3D


signal rolled(result: DiceRollResult)


@export_category("Appearance")

@export var dice_size: float = 1.0:
	set(value):
		dice_size = value
		if _mesh_instance != null:
			_create_mesh()
		if _collision_shape != null:
			_resize_collider()

@export var background_color: Color = Color(0.9, 0.9, 0.9):
	set(value):
		background_color = value
		_refresh_material_colors()

@export var face_texture_resolution: int = 256


@export_category("Physics")

@export_range(0.0, 20.0) var throw_up_strength: float = 3.5
@export_range(0.0, 10.0) var throw_horizontal_strength: float = 3.0
@export_range(1.0, 40.0) var spin_strength: float = 10.0
@export_range(0.0, 2.0) var roll_angular_damp: float = 0.5

@export_range(0.0, 1.0) var bounciness: float = 0.25:
	set(value):
		bounciness = value
		_apply_physics_material()

@export_range(0.0, 1.0) var friction: float = 0.6:
	set(value):
		friction = value
		_apply_physics_material()

@export var settle_timeout: float = 6.0


const FACE_NORMALS: Array[Vector3] = [
	Vector3.UP,
	Vector3.DOWN,
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.FORWARD,
	Vector3.BACK,
]

# Local axis used as the texture's horizontal axis for each cube face.
const FACE_U_AXES: Array[Vector3] = [
	Vector3.RIGHT,
	Vector3.RIGHT,
	Vector3.DOWN,
	Vector3.UP,
	Vector3.RIGHT,
	Vector3.RIGHT,
]

# Local axis used as the texture's vertical axis for each cube face.
# Equal to FACE_U_AXES[i].cross(FACE_NORMALS[i]) so the texture is glued to
# the outside of the cube without being mirrored (a rigid rotation can never
# un-mirror a face; the surface mapping must be right-handed with the outward
# normal, and since Vector3.BACK == (0,0,1) / FORWARD == (0,0,-1), all six
# faces satisfy that here).
const FACE_V_AXES: Array[Vector3] = [
	Vector3.BACK,
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.BACK,
	Vector3.UP,
	Vector3.DOWN,
]


var dice: Dice
var visual_definition: StandardDiceVisualResource

var _mesh_instance: MeshInstance3D
var _face_materials: Array[StandardMaterial3D] = []
var _face_viewports: Array[SubViewport] = []

var _collision_shape: CollisionShape3D

var _is_rolling: bool = false
var _launch_elapsed: float = 0.0


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	_ensure_visual()
	_ensure_collider()
	_apply_physics_material()

	continuous_cd = true
	can_sleep = true
	angular_damp = roll_angular_damp
	mass = 2.0


func _exit_tree() -> void:
	for viewport in _face_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()

	_face_viewports.clear()


# -------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------

func setup(runtime_dice: Dice) -> void:
	if runtime_dice == null:
		push_error(
			"Dice3D: Cannot setup with a null Dice."
		)
		return

	if runtime_dice.faces.is_empty():
		push_error(
			"Dice3D: Cannot setup a Dice with no faces."
		)
		return

	if runtime_dice.faces.size() > 6:
		push_error(
			"Dice3D: A cube die supports up to 6 faces, "
			+ "but this Dice has %d."
			% runtime_dice.faces.size()
		)
		return

	_ensure_visual()

	dice = runtime_dice

	if not _prepare_visual_definition():
		return

	_build_face_materials()
	_rebuild_face_textures()


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
			"Dice3D: No standard visual found for a D%d."
			% side_count
		)
		return false

	var supported_symbol_count := _get_max_layout_symbol_count()

	if supported_symbol_count < max_symbol_count:
		push_error(
			"Dice3D: Standard D%d visual supports up to %d symbols, "
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
# Mesh Creation
# -------------------------------------------------------------------

func _create_mesh() -> void:
	var mesh := _build_cube_mesh()

	_mesh_instance.mesh = mesh

	_face_materials = []

	for i in 6:
		var material := StandardMaterial3D.new()
		material.albedo_color = background_color
		material.roughness = 0.8
		mesh.surface_set_material(i, material)
		_face_materials.append(material)

	_refresh_material_colors()


func _build_cube_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()

	var half := dice_size / 2.0

	for i in 6:
		var normal := FACE_NORMALS[i]
		var u_axis := FACE_U_AXES[i]
		var v_axis := FACE_V_AXES[i]

		var center := normal * half

		var vertices := PackedVector3Array()

		# Order is chosen so the face is front-facing (CCW) from outside.
		vertices.append(center + u_axis * -half + v_axis * -half)
		vertices.append(center + u_axis * half + v_axis * -half)
		vertices.append(center + u_axis * half + v_axis * half)
		vertices.append(center + u_axis * -half + v_axis * half)

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)

		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
			normal,
			normal,
			normal,
			normal,
		])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([
			0, 1, 2,
			0, 2, 3,
		])

		mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arrays
		)

	return mesh


func _build_face_materials() -> void:
	if _mesh_instance != null:
		return

	_create_mesh()


func _refresh_material_colors() -> void:
	for material in _face_materials:
		material.albedo_color = background_color


# -------------------------------------------------------------------
# Collision
# -------------------------------------------------------------------

func _ensure_collider() -> void:
	if _collision_shape != null:
		return

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"

	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * dice_size
	_collision_shape.shape = shape

	add_child(_collision_shape)


func _resize_collider() -> void:
	if _collision_shape == null:
		return

	var shape := _collision_shape.shape as BoxShape3D

	if shape != null:
		shape.size = Vector3.ONE * dice_size


func _apply_physics_material() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = bounciness
	material.friction = friction
	physics_material_override = material


# -------------------------------------------------------------------
# Face Textures
# -------------------------------------------------------------------

func _rebuild_face_textures() -> void:
	_clear_face_viewports()

	if dice == null:
		return

	for i in dice.faces.size():
		_create_face_texture(i)

	_refresh_material_colors()


func _clear_face_viewports() -> void:
	for viewport in _face_viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()

	_face_viewports.clear()


func _create_face_texture(face_index: int) -> void:
	var face: DiceFace = dice.faces[face_index]

	if face == null:
		return

	var layout := _get_layout_for_face(face)

	var viewport := SubViewport.new()
	viewport.name = "Face%dViewport" % face_index
	viewport.size = Vector2i(
		face_texture_resolution,
		face_texture_resolution
	)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var background := ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	var face_2d := DiceFace2D.new()
	face_2d.name = "Face"
	face_2d.face_size = Vector2(
		face_texture_resolution / 2.0,
		face_texture_resolution / 2.0
	)
	face_2d.scale = Vector2(2.0, 2.0)

	if layout != null:
		face_2d.setup(face, layout)

	viewport.add_child(background)
	viewport.add_child(face_2d)
	add_child(viewport)

	_face_viewports.append(viewport)

	if face_index < _face_materials.size():
		_face_materials[face_index].albedo_texture = viewport.get_texture()
		_face_materials[face_index].albedo_color = Color.WHITE


# -------------------------------------------------------------------
# Visual
# -------------------------------------------------------------------

func _ensure_visual() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MeshInstance"

	add_child(_mesh_instance)

	_create_mesh()


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

# Throws the die across the tray. The die is the final authority on the
# result: when physics settle it reports whichever face actually ended up
# on top.
func roll() -> void:
	if dice == null:
		push_error(
			"Dice3D: Cannot roll before setup() has been called."
		)
		return

	_is_rolling = true
	_launch_elapsed = 0.0

	freeze = false
	sleeping = false

	var direction := Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)

	if direction.length_squared() < 0.01:
		direction = Vector2(1.0, 0.0)

	direction = direction.normalized()

	var horizontal := randf_range(0.7, 1.3) * throw_horizontal_strength

	linear_velocity = Vector3(
		direction.x * horizontal,
		randf_range(0.8, 1.3) * throw_up_strength,
		direction.y * horizontal
	)

	# Tumble end-over-end in the direction of travel (a horizontal axis
	# perpendicular to the throw) with a mild vertical wobble, so the die
	# rolls like a real thrown die instead of spinning on the spot.
	var forward := Vector3(direction.x, 0.0, direction.y)
	var tumble_axis := Vector3(direction.y, 0.0, -direction.x)
	var spin := randf_range(
		spin_strength * 0.8,
		spin_strength
	) * (1.0 if randi() % 2 == 0 else -1.0)

	angular_velocity = (
		tumble_axis * spin
		+ Vector3.UP * randf_range(-spin * 0.25, spin * 0.25)
	)


func _physics_process(delta: float) -> void:
	if not _is_rolling:
		return

	_launch_elapsed += delta

	if sleeping or _launch_elapsed >= settle_timeout:
		_settle()


func _settle() -> void:
	_is_rolling = false

	if dice == null:
		return

	var face_index := get_top_face_index()

	if face_index < 0:
		return

	var result := DiceRollResult.new(dice.faces[face_index])
	dice.last_result = result

	rolled.emit(result)

	# Safety net: if the cube ended up below the floor (a fast spin can
	# tunnel through a static edge in rare cases), place it back on top of
	# its landing spot instead of leaving it floating underneath.
	if global_position.y < -0.01:
		global_transform = Transform3D(
			Basis.IDENTITY,
			Vector3(
				global_position.x,
				dice_size / 2.0,
				global_position.z
			)
		)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		sleeping = true


# -------------------------------------------------------------------
# Results
# -------------------------------------------------------------------

func get_top_face_index() -> int:
	var best_index := 0
	var best_dot := -INF

	for i in FACE_NORMALS.size():
		var world_normal: Vector3 = basis * FACE_NORMALS[i]
		var alignment := world_normal.dot(Vector3.UP)

		if alignment > best_dot:
			best_dot = alignment
			best_index = i

	return best_index


func get_result() -> DiceRollResult:
	if dice == null:
		return null

	return dice.get_last_result()


func get_visible_symbols() -> Array[DiceSymbolResource]:
	var result := get_result()

	if result == null:
		return []

	if result.face == null:
		return []

	return result.face.symbols