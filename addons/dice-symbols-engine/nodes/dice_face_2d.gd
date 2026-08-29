class_name DiceFace2D
extends Node2D


@export var face_size: Vector2 = Vector2(256.0, 256.0)

var face: DiceFace
var layout: DiceFaceLayoutResource


func setup(
	runtime_face: DiceFace,
	face_layout: DiceFaceLayoutResource
) -> void:
	face = runtime_face
	layout = face_layout

	_rebuild()


func _rebuild() -> void:
	_clear_symbols()

	if face == null:
		return

	if layout == null:
		push_error("DiceFace2D: No layout provided.")
		return

	if layout.entries.size() != face.symbols.size():
		push_error(
			"DiceFace2D: Layout has %d entries but face has %d symbols."
			% [
				layout.entries.size(),
				face.symbols.size()
			]
		)
		return

	for i in face.symbols.size():
		_create_symbol_sprite(
			face.symbols[i],
			layout.entries[i]
		)


func _clear_symbols() -> void:
	for child in get_children():
		child.queue_free()


func _create_symbol_sprite(
	symbol: DiceSymbolResource,
	entry: DiceFaceLayoutEntryResource
) -> void:
	if symbol == null:
		push_error("DiceFace2D: Symbol is null.")
		return

	if entry == null:
		push_error("DiceFace2D: Layout entry is null.")
		return

	if symbol.icon == null:
		push_error(
			"DiceFace2D: Symbol '%s' has no icon."
			% symbol.name
		)
		return

	var sprite := Sprite2D.new()

	sprite.texture = symbol.icon
	sprite.position = _get_position(entry)
	sprite.rotation = entry.rotation
	sprite.scale = entry.scale

	add_child(sprite)


func _get_position(entry: DiceFaceLayoutEntryResource) -> Vector2:
	var margin := clamp(layout.margin, 0.0, 0.5)
	var usable_size: Vector2 = face_size * (1.0 - margin * 2.0)

	return entry.position * (usable_size / 2.0)

func get_face_size() -> int:
	return face.get_faces
