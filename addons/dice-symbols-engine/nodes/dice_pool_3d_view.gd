class_name DicePool3DView
extends SubViewportContainer


signal dice_added(dice: Dice)
signal dice_removed(dice: Dice)

signal dice_rolled(dice: Dice, result: DiceRollResult)
signal rolled


const PIXEL_SHADER := preload(
	"res://addons/dice-symbols-engine/shaders/post_pixel.gdshader"
)


@export_category("Camera")

# Height of the top-down camera above the pool floor.
@export var camera_height: float = 20.0:
	set(value):
		camera_height = value
		if is_inside_tree():
			_apply_camera_transform()

# Manual orthographic half-height framing (used only when
# fit_whole_tray is disabled).
@export var camera_size: float = 4.4:
	set(value):
		camera_size = maxf(value, 0.5)
		if is_inside_tree():
			_apply_camera_transform()

# Auto-fit the entire tray (dice box) inside the view, adapting to the
# container's aspect ratio.
@export var fit_whole_tray: bool = true:
	set(value):
		fit_whole_tray = value
		if is_inside_tree():
			_apply_camera_transform()

# Size of the dice box footprint (width, depth) used when fitting.
# Matches the tray walls: floor is 9x7, outer rim footprint is 9.4x7.4.
@export var tray_size: Vector2 = Vector2(9.4, 7.4):
	set(value):
		tray_size = value
		if is_inside_tree():
			_apply_camera_transform()

# Extra framing margin (1.0 = box exactly fits, 1.1 = 10% border).
@export_range(1.0, 3.0) var tray_fill: float = 1.25:
	set(value):
		tray_fill = value
		if is_inside_tree():
			_apply_camera_transform()


@export_category("Post Processing")

# Retro PS2-style pixel filter applied inside the 3D view.
@export var post_processing_enabled: bool = true:
	set(value):
		post_processing_enabled = value
		if is_inside_tree():
			_apply_view_settings()

@export_range(1, 16, 1) var pixel_size: int = 3:
	set(value):
		pixel_size = maxi(value, 1)
		if is_inside_tree():
			_apply_view_settings()

@export_range(0.0, 1.0) var scanline_strength: float = 0.22:
	set(value):
		scanline_strength = value
		if is_inside_tree():
			_apply_view_settings()

@export_range(0.0, 1.0) var vignette_strength: float = 0.35:
	set(value):
		vignette_strength = value
		if is_inside_tree():
			_apply_view_settings()

@export_range(0.0, 1.0) var palette_strength: float = 0.55:
	set(value):
		palette_strength = value
		if is_inside_tree():
			_apply_view_settings()

@export_range(0.0, 1.0) var dither_strength: float = 0.5:
	set(value):
		dither_strength = value
		if is_inside_tree():
			_apply_view_settings()

@export_range(0.0, 1.0) var shimmer: float = 0.3:
	set(value):
		shimmer = value
		if is_inside_tree():
			_apply_view_settings()


@export_category("Presentation")

# Tray background material used for the floor/visual behind the dice.
@export var tray_background_material: StandardMaterial3D:
	set(value):
		tray_background_material = value
		if is_inside_tree():
			_apply_tray_background()

# Dice material (face albedo: color/texture) applied to created dice.
@export var dice_material: StandardMaterial3D:
	set(value):
		dice_material = value
		if is_inside_tree():
			_apply_dice_material()


@onready var viewport: SubViewport = $Viewport
@onready var pool_3d: DicePool3D = $Viewport/DicePool3D
@onready var camera: Camera3D = $Viewport/Camera3D
@onready var floor_visual: MeshInstance3D = $Viewport/Floor

var _pending_setup_pool: DicePool

var _post_fx: ColorRect
var _post_material: ShaderMaterial


# -------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------

func _ready() -> void:
	stretch = true

	_forward_pool_signals()

	if _pending_setup_pool != null:
		var runtime_pool := _pending_setup_pool
		_pending_setup_pool = null
		_apply_setup(runtime_pool)

	_apply_view_settings()
	_apply_camera_transform()

	if not viewport.size_changed.is_connected(_apply_camera_transform):
		viewport.size_changed.connect(_apply_camera_transform)


func _enter_tree() -> void:
	stretch = true


func _forward_pool_signals() -> void:
	if pool_3d == null:
		return

	if not pool_3d.dice_added.is_connected(_on_pool_dice_added):
		pool_3d.dice_added.connect(_on_pool_dice_added)

	if not pool_3d.dice_removed.is_connected(_on_pool_dice_removed):
		pool_3d.dice_removed.connect(_on_pool_dice_removed)

	if not pool_3d.dice_rolled.is_connected(_on_pool_dice_rolled):
		pool_3d.dice_rolled.connect(_on_pool_dice_rolled)

	if not pool_3d.rolled.is_connected(_on_pool_rolled):
		pool_3d.rolled.connect(_on_pool_rolled)


func _on_pool_dice_removed(dice: Dice) -> void:
	dice_removed.emit(dice)


func _on_pool_dice_rolled(
	dice: Dice,
	result: DiceRollResult
) -> void:

	dice_rolled.emit(dice, result)


func _on_pool_rolled() -> void:
	rolled.emit()


# -------------------------------------------------------------------
# Camera
# -------------------------------------------------------------------

func _apply_camera_transform() -> void:
	if camera == null:
		return

	camera.position = Vector3(0.0, camera_height, 0.0)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	if fit_whole_tray:
		var aspect := viewport.size.x / maxf(viewport.size.y, 1.0)
		var half_x := tray_size.x / 2.0
		var half_y := tray_size.y / 2.0
		camera.size = maxf(half_y, half_x / aspect) * tray_fill * 1.001
	else:
		camera.size = camera_size


# -------------------------------------------------------------------
# Post Processing
# -------------------------------------------------------------------

func _apply_view_settings() -> void:
	if viewport == null:
		return

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if post_processing_enabled:
		_ensure_post_fx()
		_post_material.set_shader_parameter("pixel_size", pixel_size)
		_post_material.set_shader_parameter(
			"scanline_strength",
			scanline_strength
		)
		_post_material.set_shader_parameter(
			"vignette_strength",
			vignette_strength
		)
		_post_material.set_shader_parameter("palette_strength", palette_strength)
		_post_material.set_shader_parameter("dither_strength", dither_strength)
		_post_material.set_shader_parameter("shimmer", shimmer)
	else:
		_remove_post_fx()

	_apply_tray_background()
	_apply_dice_material()


func _ensure_post_fx() -> void:
	if _post_fx != null and is_instance_valid(_post_fx):
		return

	_post_material = ShaderMaterial.new()
	_post_material.shader = PIXEL_SHADER

	_post_fx = ColorRect.new()
	_post_fx.name = "PostFX"
	_post_fx.material = _post_material
	_post_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(_post_fx)


func _remove_post_fx() -> void:
	if _post_fx != null and is_instance_valid(_post_fx):
		_post_fx.queue_free()

	_post_fx = null


# -------------------------------------------------------------------
# Presentation
# -------------------------------------------------------------------

func _apply_tray_background() -> void:
	if tray_background_material == null:
		return

	if floor_visual == null or not is_instance_valid(floor_visual):
		return

	floor_visual.material_override = tray_background_material


func _apply_dice_material() -> void:
	if dice_material == null:
		return

	if pool_3d == null:
		return

	var dice_list: Array = pool_3d.get_dice()

	for die in dice_list:
		var visual: Dice3D = pool_3d.get_dice_visual(die)

		if visual == null or not is_instance_valid(visual):
			continue

		var mats: Array[StandardMaterial3D] = visual._face_materials

		for i in mats.size():
			var material: StandardMaterial3D = mats[i]
			material.albedo_texture = dice_material.albedo_texture
			material.albedo_color = dice_material.albedo_color
			material.roughness = dice_material.roughness


func _on_pool_dice_added(dice: Dice) -> void:
	dice_added.emit(dice)

	if dice_material != null:
		_apply_dice_material()


# -------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------

func setup(runtime_pool: DicePool) -> void:
	if not is_inside_tree() or pool_3d == null:
		_pending_setup_pool = runtime_pool
		return

	_apply_setup(runtime_pool)


func _apply_setup(runtime_pool: DicePool) -> void:
	if runtime_pool == null:
		push_error(
			"DicePool3DView: Cannot setup with a null DicePool."
		)
		return

	if pool_3d == null:
		return

	_forward_pool_signals()

	pool_3d.setup(runtime_pool)


func get_dice_pool_3d() -> DicePool3D:
	return pool_3d


# -------------------------------------------------------------------
# Dice Management
# -------------------------------------------------------------------

func add_dice(die: Dice) -> bool:
	if pool_3d == null:
		return false

	return pool_3d.add_dice(die)


func remove_dice(die: Dice) -> bool:
	if pool_3d == null:
		return false

	return pool_3d.remove_dice(die)


func clear() -> void:
	if pool_3d == null:
		return

	pool_3d.clear()


func get_dice() -> Array[Dice]:
	if pool_3d == null:
		return []

	return pool_3d.get_dice()


# -------------------------------------------------------------------
# Rolling
# -------------------------------------------------------------------

func roll() -> void:
	if pool_3d == null:
		return

	pool_3d.roll()


func roll_dice_multiple(
	dice_to_roll: Array[Dice]
) -> void:

	if pool_3d == null:
		return

	pool_3d.roll_dice_multiple(dice_to_roll)


func add_and_roll_dice(
	dice_to_roll: Array[Dice]
) -> void:

	if pool_3d == null:
		return

	pool_3d.add_and_roll_dice(dice_to_roll)


# -------------------------------------------------------------------
# Results
# -------------------------------------------------------------------

func get_results() -> Array[DiceRollResult]:
	if pool_3d == null:
		return []

	return pool_3d.get_results()


func get_symbols() -> Array[DiceSymbolResource]:
	if pool_3d == null:
		return []

	return pool_3d.get_symbols()
