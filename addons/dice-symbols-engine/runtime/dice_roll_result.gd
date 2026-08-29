class_name DiceRollResult
extends RefCounted


var face: DiceFace


func _init(rolled_face: DiceFace) -> void:
	face = rolled_face


func has_symbol(symbol: DiceSymbolResource) -> bool:
	return symbol in face.symbols


func get_symbols() -> Array[DiceSymbolResource]:
	return face.symbols
