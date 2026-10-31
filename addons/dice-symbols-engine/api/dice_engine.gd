class_name DiceEngine
extends RefCounted


const DICE_2D_SCENE := preload(
	"res://addons/dice-symbols-engine/nodes/dice_2d.tscn"
)

const DICE_3D_SCENE := preload(
	"res://addons/dice-symbols-engine/nodes/dice_3d.tscn"
)

const DICE_POOL_3D_SCENE := preload(
	"res://addons/dice-symbols-engine/nodes/dice_pool_3d.tscn"
)

const DICE_POOL_3D_VIEW_SCENE := preload(
	"res://addons/dice-symbols-engine/nodes/dice_pool_3d_view.tscn"
)


static func create_dice(
	dice_resource: DiceResource
) -> Dice:
	if dice_resource == null:
		push_error(
			"DiceEngine: Cannot create Dice from a null DiceResource."
		)
		return null

	return Dice.from_resource(dice_resource)


static func create_dice_2d(
	dice_resource: DiceResource
) -> Dice2D:
	if dice_resource == null:
		push_error(
			"DiceEngine: Cannot create Dice2D from a null DiceResource."
		)
		return null

	var dice := create_dice(dice_resource)

	if dice == null:
		return null

	return create_dice_2d_from_dice(dice)


static func create_dice_2d_from_dice(
	dice: Dice
) -> Dice2D:
	if dice == null:
		push_error(
			"DiceEngine: Cannot create Dice2D from a null Dice."
		)
		return null

	var dice_2d := DICE_2D_SCENE.instantiate() as Dice2D

	if dice_2d == null:
		push_error(
			"DiceEngine: Failed to instantiate Dice2D."
		)
		return null

	dice_2d.setup(dice)

	return dice_2d


# -------------------------------------------------------------------
# 3D Dice
# -------------------------------------------------------------------

static func create_dice_3d(
	dice_resource: DiceResource
) -> Dice3D:

	if dice_resource == null:
		push_error(
			"DiceEngine: Cannot create Dice3D from a null DiceResource."
		)
		return null

	var dice := create_dice(dice_resource)

	if dice == null:
		return null

	return create_dice_3d_from_dice(dice)


static func create_dice_3d_from_dice(
	dice: Dice
) -> Dice3D:

	if dice == null:
		push_error(
			"DiceEngine: Cannot create Dice3D from a null Dice."
		)
		return null

	var dice_3d := DICE_3D_SCENE.instantiate() as Dice3D

	if dice_3d == null:
		push_error(
			"DiceEngine: Failed to instantiate Dice3D."
		)
		return null

	dice_3d.setup(dice)

	return dice_3d


# -------------------------------------------------------------------
# 3D Dice Pool
# -------------------------------------------------------------------

static func create_dice_pool_3d(
	runtime_pool: DicePool
) -> DicePool3D:

	if runtime_pool == null:
		push_error(
			"DiceEngine: Cannot create DicePool3D from a null DicePool."
		)
		return null

	var pool_3d := DICE_POOL_3D_SCENE.instantiate() as DicePool3D

	if pool_3d == null:
		push_error(
			"DiceEngine: Failed to instantiate DicePool3D."
		)
		return null

	pool_3d.setup(runtime_pool)

	return pool_3d


static func create_dice_pool_3d_view(
	runtime_pool: DicePool
) -> DicePool3DView:

	if runtime_pool == null:
		push_error(
			"DiceEngine: Cannot create DicePool3DView from a null DicePool."
		)
		return null

	var pool_3d_view := (
		DICE_POOL_3D_VIEW_SCENE.instantiate() as DicePool3DView
	)

	if pool_3d_view == null:
		push_error(
			"DiceEngine: Failed to instantiate DicePool3DView."
		)
		return null

	pool_3d_view.setup(runtime_pool)

	return pool_3d_view
