class_name DiceFace
extends RefCounted


var symbols: Array[DiceSymbolResource]


static func from_resource(
	resource: DiceFaceResource
) -> DiceFace:
	var face := DiceFace.new()

	face.symbols = resource.symbols.duplicate()

	return face
