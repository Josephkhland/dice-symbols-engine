class_name DiceFaceLayoutEntryResource
extends Resource

@export var position: Vector2
@export var rotation: float
@export var scale: Vector2 = Vector2.ONE


func get_transform() -> Transform2D:
	return Transform2D(
		rotation,
		position
	).scaled(scale)
