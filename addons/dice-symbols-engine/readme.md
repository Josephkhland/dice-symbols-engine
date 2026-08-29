# Dice Symbols Engine

A Godot addon for creating, rolling, displaying, and managing customizable dice and dice pools.

The engine separates **what a die is** from **how a die is displayed**, allowing games to create dice from reusable resources while freely modifying their runtime state.

It supports:

- Custom dice with any number of faces
- Multiple symbols on each face
- Symbol icons and configurable layouts
- Runtime dice instances
- Dice pools
- Aggregating symbols from multiple dice
- 2D dice visualization
- Dice rolling animations
- Dice pool visualization
- Scatter and grid layouts
- Selecting and dragging dice
- Detecting dice dragged outside a pool
- Extensible signals for integrating dice with game logic

---

# Getting Started

## 1. Create a Dice Resource

The addon uses Godot `Resource`s to define dice.

A `DiceResource` describes the base configuration of a die:

```text
DiceResource
    ├── Face
    │    ├── Symbol
    │    ├── Symbol
    │    └── ...
    │
    ├── Face
    │    ├── Symbol
    │    └── ...
    │
    └── ...
```

A face can contain one or more symbols.

For example, a simple six-sided die could contain:

```text
Face 1 → Sword
Face 2 → Sword
Face 3 → Shield
Face 4 → Shield
Face 5 → Magic
Face 6 → Skull
```

The exact meaning of the symbols is determined by the game using the addon.

The addon only provides the dice and their results.

---

# Runtime Dice

A `DiceResource` is a **definition/template**.

When your game wants to actually use a die, create a runtime `Dice` from it.

```gdscript
var die := Dice.from_resource(my_dice_resource)
```

The distinction is important:

```text
DiceResource
    ↓
    Template / Definition

Dice
    ↓
    Runtime instance
```

Your game can create multiple independent runtime dice from the same resource:

```gdscript
var die_1 := Dice.from_resource(d6_resource)
var die_2 := Dice.from_resource(d6_resource)
var die_3 := Dice.from_resource(d6_resource)
```

These are three separate runtime dice.

This is useful when a game needs to modify individual dice during gameplay.

For example, a game could have a basic die resource and then modify a runtime die when the player upgrades it.

---

# Rolling a Die

A runtime die can be rolled directly:

```gdscript
var die := Dice.from_resource(dice_resource)

die.roll()
```

After rolling, the die stores its latest result.

```gdscript
var result := die.get_last_result()
```

A `DiceRollResult` contains the resulting face.

You can access its symbols:

```gdscript
for symbol in result.face.symbols:
    print(symbol.name)
```

The addon does not decide what those symbols do.

For example, your game might interpret:

```text
Sword
Sword
Shield
```

as:

```text
Deal 2 damage
Block 1 damage
```

The game owns that interpretation.

---

# DiceEngine

`DiceEngine` provides convenient factory methods for creating dice and their visual representations.

Instead of manually instantiating nodes and converting resources, games can use the engine API.

## Create a runtime Dice

```gdscript
var die := DiceEngine.create_dice(dice_resource)
```

## Create a Dice2D from a resource

```gdscript
var dice_2d := DiceEngine.create_dice_2d(dice_resource)

add_child(dice_2d)

dice_2d.position = Vector2(500, 300)
```

## Create a Dice2D from an existing runtime Dice

This is useful when your game has already created or modified a runtime die.

```gdscript
var die := Dice.from_resource(dice_resource)

# Modify the runtime die here...

var dice_2d := DiceEngine.create_dice_2d_from_dice(die)

add_child(dice_2d)
```

The second approach is especially useful for games where dice can be upgraded, modified, or otherwise changed during gameplay.

---

# Dice2D

`Dice2D` is the visual representation of a runtime `Dice`.

It is a `Node2D`, so it can be positioned, moved, animated, and added to your game's scene tree.

A typical usage looks like:

```gdscript
var dice_2d := DiceEngine.create_dice_2d(dice_resource)

add_child(dice_2d)

dice_2d.position = Vector2(500, 300)
dice_2d.roll()
```

The `Dice2D` handles:

- Drawing the die
- Displaying its symbols
- Selecting the appropriate visual layout
- Rolling animation
- Pointer interaction
- Exposing the resulting `DiceRollResult`

---

# Dice2D Setup

If you create a `Dice2D` through `DiceEngine`, the runtime die is already assigned.

If you instantiate a `Dice2D` manually, call:

```gdscript
var dice_2d := preload(
    "res://addons/dice-symbols-engine/nodes/dice_2d.tscn"
).instantiate()

add_child(dice_2d)

var die := Dice.from_resource(dice_resource)

dice_2d.setup(die)
```

In most cases, however, using `DiceEngine` is simpler.

---

# Rolling a Dice2D

To roll its associated runtime die:

```gdscript
dice_2d.roll()
```

The visual die will:

1. Begin its roll animation.
2. Display several random faces.
3. Stabilize on the resulting face.
4. Emit the `rolled` signal.

You can listen for the result:

```gdscript
dice_2d.rolled.connect(_on_dice_rolled)
```

```gdscript
func _on_dice_rolled(result: DiceRollResult) -> void:
    print("Rolled face: ", result.face.name)

    for symbol in result.face.symbols:
        print("Symbol: ", symbol.name)
```

---

# Reading the Last Result

The visual object can expose the runtime die's most recent result:

```gdscript
var result := dice_2d.get_result()
```

This is useful when the visual die is being moved around the scene after it has been rolled.

For example, a game could allow the player to roll a die, move it around, and inspect its result later.

---

# DicePool

`DicePool` represents a collection of runtime dice.

It is the **logical** side of a dice pool.

It does not care about where the dice are displayed.

A pool can contain any number of dice:

```gdscript
var pool := DicePool.new()

var die_1 := Dice.from_resource(d6_resource)
var die_2 := Dice.from_resource(d6_resource)
var die_3 := Dice.from_resource(d6_resource)

pool.add_dice(die_1)
pool.add_dice(die_2)
pool.add_dice(die_3)
```

For convenience, multiple dice can be added at once:

```gdscript
pool.add_dice_multiple([
    die_1,
    die_2,
    die_3
])
```

---

# Rolling a DicePool

A pool can roll its dice:

```gdscript
pool.roll()
```

Individual dice can also be rolled:

```gdscript
pool.roll_dice(die_1)
```

The pool keeps track of the runtime dice and their latest results.

This makes it possible for a game to build systems such as:

- Character dice pools
- Attack rolls
- Skill checks
- Resource dice
- Dice drafting
- Dice manipulation
- Rerolls
- Adding bonus dice
- Removing dice
- Upgrading individual dice

---

# Accessing Dice in a Pool

The dice contained in a pool can be accessed through:

```gdscript
var dice := pool.dice
```

This allows the game to inspect or manipulate the individual runtime dice.

For example:

```gdscript
for die in pool.dice:
    var result := die.get_last_result()

    if result == null:
        continue

    print(result.face.name)
```

---

# Aggregating Symbols

Dice pools are particularly useful when a game cares about the combined symbols produced by several dice.

For example:

```text
Die 1 → Sword, Sword
Die 2 → Shield
Die 3 → Sword, Magic
```

The pool can be used as the basis for interpreting:

```text
Sword × 3
Shield × 1
Magic × 1
```

The actual interpretation of these symbols belongs to the game.

This allows the same dice engine to be used for completely different games.

---

# DicePool2D

`DicePool2D` is the visual counterpart to `DicePool`.

It manages the visual representation and interaction of multiple dice.

The separation is:

```text
DicePool
    Logical dice
    Rolling
    Results
    Adding/removing dice

DicePool2D
    Visual dice
    Positioning
    Animation
    Selection
    Dragging
    Layout
    Mouse interaction
```

A `DicePool2D` is a `Node2D` and can therefore be placed directly into your scene.

---

# Creating a DicePool2D

Create the logical pool first:

```gdscript
var pool := DicePool.new()

pool.add_dice_multiple([
    DiceEngine.create_dice(d6_resource),
    DiceEngine.create_dice(d6_resource),
    DiceEngine.create_dice(d6_resource)
])
```

Then create its visual representation:

```gdscript
var pool_2d := DiceEngine.create_dice_pool_2d(pool)

add_child(pool_2d)
```

The `DicePool2D` will create visual dice for the runtime dice contained in the pool.

---

# Setting Up a DicePool2D Manually

If you instantiate a `DicePool2D` yourself, provide it with a runtime `DicePool`:

```gdscript
var pool_2d := preload(
    "res://addons/dice-symbols-engine/nodes/dice_pool_2d.tscn"
).instantiate()

add_child(pool_2d)

pool_2d.setup(pool)
```

Once setup is complete, changes to the logical pool are reflected by the visual pool.

---

# Rolling a DicePool2D

The visual pool can be asked to roll:

```gdscript
pool_2d.roll()
```

The logical dice are rolled first, and the visual dice then animate toward their already-determined results.

This separation is intentional.

The animation does not determine the game result.

The runtime `Dice` determines the result.

The visual layer displays it.

---

# Scatter Layout

A `DicePool2D` can scatter dice throughout its configured pool area.

This is useful for games where dice should feel loose or physical.

For example:

```text
┌──────────────────────────────┐
│                              │
│     ◇          ◇             │
│                 ◇            │
│  ◇                    ◇      │
│                              │
└──────────────────────────────┘
```

The pool exposes configuration for:

- Pool size
- Pool offset
- Scatter margin
- Random rotation

---

# Grid Layout

The pool can also arrange dice into a configurable grid.

For example:

```text
┌──────────────────────────────┐
│                              │
│      ◇    ◇    ◇    ◇       │
│      ◇    ◇    ◇    ◇       │
│                              │
└──────────────────────────────┘
```

The number of columns can be configured.

Grid dice use no random rotation.

The grid can also be centered inside the pool area.

This is useful for games where dice need to be presented in a clean, organized arrangement.

---

# Selecting Dice

`DicePool2D` can optionally allow dice to be selected.

Selection is controlled through its interaction properties.

```gdscript
pool_2d.selectable = true
```

When a die is selected:

```gdscript
pool_2d.dice_selected.connect(_on_dice_selected)
```

```gdscript
func _on_dice_selected(die: Dice) -> void:
    print("Selected die: ", die)
```

The current selection can be retrieved with:

```gdscript
var selected := pool_2d.get_selected_dice()
```

The pool can operate with either single selection or multiple selection.

---

# Dragging Dice

DicePool2D can optionally allow dice to be dragged.

```gdscript
pool_2d.draggable = true
```

Dragging generates events such as:

```gdscript
pool_2d.dice_drag_started.connect(_on_drag_started)
pool_2d.dice_dragged.connect(_on_dragged)
pool_2d.dice_dragged_out.connect(_on_dragged_out)
```

For example:

```gdscript
func _on_drag_started(die: Dice) -> void:
    print("Started dragging: ", die)
```

A game can use this to create mechanics such as:

- Dragging dice onto abilities
- Moving dice between character areas
- Selecting dice by dragging them
- Removing dice from a pool
- Dragging dice into another pool
- Dragging dice onto game objects

---

# Dice Dragged Outside the Pool

When a die is dragged outside the pool area, `DicePool2D` emits:

```gdscript
dice_dragged_out(dice, side)
```

The `side` tells the game which side of the pool the die exited from:

```text
        TOP
         ↑

LEFT ← POOL → RIGHT

         ↓
       BOTTOM
```

For example:

```gdscript
func _on_dice_dragged_out(
    die: Dice,
    side: DicePool2D.ExitSide
) -> void:

    match side:
        DicePool2D.ExitSide.TOP:
            print("Die left through the top.")

        DicePool2D.ExitSide.RIGHT:
            print("Die left through the right.")

        DicePool2D.ExitSide.BOTTOM:
            print("Die left through the bottom.")

        DicePool2D.ExitSide.LEFT:
            print("Die left through the left.")
```

The addon does not decide what should happen next.

Your game can decide whether to:

- Remove the die
- Move it to another pool
- Place it on a character
- Treat it as a selected die
- Return it to its original position
- Trigger another game mechanic

---

# Signals

Signals are the primary way the visual layer communicates with the game.

## Dice2D

`Dice2D` exposes:

```gdscript
pointer_pressed
pointer_released
rolled(result)
```

The `rolled` signal provides the actual `DiceRollResult`.

---

## DicePool2D

`DicePool2D` exposes:

```gdscript
dice_added(dice)
dice_removed(dice)

dice_selected(dice)
dice_deselected(dice)

dice_drag_started(dice)
dice_dragged(dice, position)
dice_dragged_out(dice, side)

dice_rolled(dice, result)
rolled
```

These allow the game to react to dice without needing to constantly inspect the visual nodes.

---

# Example: A Complete Simple Dice Roll

A minimal game could look like this:

```gdscript
extends Node2D

@export var dice_resource: DiceResource

var dice_2d: Dice2D


func _ready() -> void:
    dice_2d = DiceEngine.create_dice_2d(
        dice_resource
    )

    add_child(dice_2d)

    dice_2d.position = Vector2(400, 300)

    dice_2d.rolled.connect(
        _on_dice_rolled
    )


func _on_roll_button_pressed() -> void:
    dice_2d.roll()


func _on_dice_rolled(
    result: DiceRollResult
) -> void:

    for symbol in result.face.symbols:
        print(symbol.name)
```

That's enough to create a functional dice game.

---

# Example: A Dice Pool

```gdscript
extends Node2D

@export var dice_resource: DiceResource

var dice_pool: DicePool
var dice_pool_2d: DicePool2D


func _ready() -> void:
    dice_pool = DicePool.new()

    dice_pool.add_dice_multiple([
        DiceEngine.create_dice(dice_resource),
        DiceEngine.create_dice(dice_resource),
        DiceEngine.create_dice(dice_resource),
        DiceEngine.create_dice(dice_resource)
    ])

    dice_pool_2d = DiceEngine.create_dice_pool_2d(
        dice_pool
    )

    add_child(dice_pool_2d)

    dice_pool_2d.rolled.connect(
        _on_pool_rolled
    )


func _on_roll_pressed() -> void:
    dice_pool_2d.roll()


func _on_pool_rolled() -> void:
    print("All dice finished rolling.")
```

---

# Visual Layouts

The addon includes a library of standard dice visuals.

A visual definition describes how symbols should be arranged on a face.

For example, a standard D6 can use layouts such as:

```text
1 symbol

      ●


2 symbols

●
          ●


3 symbols

●
    ●
          ●


4 symbols

●       ●

●       ●


5 symbols

●       ●
    ●
●       ●


6 symbols

●       ●
●       ●
●       ●
```

The layout is selected according to the number of symbols on a face.

---

# How Dice2D Chooses a Layout

`Dice2D` does not store visual layouts inside the runtime `Dice`.

Instead, it determines the appropriate standard visual based on the number of sides of the die.

For example:

```text
D6
 ↓
Standard D6 visual
 ↓
Face has 4 symbols
 ↓
Find layout containing 4 positions
 ↓
Display the 4 symbols
```

This keeps gameplay data separate from presentation data.

A `Dice` therefore does not need to know anything about:

- Sprite positions
- Margins
- Rotation
- Scale
- Polygon borders
- 2D presentation

---

# Supported Visuals

A visual definition must support enough symbol positions for the dice being displayed.

For example, if a D6 visual supports up to 6 symbols:

```text
D6
✓ Face with 1 symbol
✓ Face with 2 symbols
✓ Face with 3 symbols
✓ Face with 4 symbols
✓ Face with 5 symbols
✓ Face with 6 symbols
```

If a die requires more symbols than its available visual definition supports, `Dice2D` reports an error instead of producing an invalid layout.

Similarly, if no standard visual exists for the die's number of sides, the visual cannot be created automatically.

---

# Custom Game Logic

The engine intentionally does not contain game-specific rules.

For example, the addon can tell you:

```text
Sword
Sword
Shield
Magic
```

Your game decides what that means.

One game might interpret this as:

```text
2 Attack
1 Defense
1 Mana
```

Another game might interpret it as:

```text
Combo ×2
Block
Spell
```

Another game might use the symbols as resources rather than combat results.

This separation allows the addon to be reused across many different games.

---

# Recommended Architecture

A typical game using the addon can follow this structure:

```text
GAME
│
├── DiceResource
│       Defines the base die
│
├── DiceEngine
│       Creates runtime objects
│
├── Dice
│       Runtime game data
│
├── DicePool
│       Runtime collection of dice
│
├── Dice2D
│       Visual representation of one die
│
└── DicePool2D
        Visual representation and interaction
        for multiple dice
```

The game should generally treat:

```text
Dice
DicePool
DiceRollResult
```

as gameplay data.

And:

```text
Dice2D
DicePool2D
```

as presentation and interaction.

---

# What the Addon Handles

The addon handles:

- Creating dice
- Runtime dice instances
- Rolling dice
- Dice results
- Dice pools
- Adding/removing dice
- Visualizing dice
- Visualizing dice pools
- Symbol placement
- Standard visual layouts
- Rolling animations
- Selecting dice
- Dragging dice
- Detecting dice leaving a pool
- Visual pool arrangements

---

# What the Game Handles

The game should handle:

- What symbols mean
- Damage
- Healing
- Resources
- Combat rules
- Player turns
- Enemy behavior
- Reroll rules
- When dice can be rolled
- When dice can be removed
- What happens when dice leave a pool
- How dice interact with other game objects
- Game-specific upgrades and modifiers

The addon provides the dice system.

The game provides the rules.

---

# Quick API Reference

## Runtime Dice

```gdscript
Dice.from_resource(resource)
DiceEngine.create_dice(resource)

die.roll()
die.get_last_result()
```

## Visual Dice

```gdscript
DiceEngine.create_dice_2d(resource)
DiceEngine.create_dice_2d_from_dice(die)

dice_2d.setup(die)
dice_2d.roll()
dice_2d.roll_result(result)
dice_2d.get_result()
```

## Dice Pool

```gdscript
var pool := DicePool.new()

pool.add_dice(die)
pool.add_dice_multiple(dice)

pool.remove_dice(die)
pool.clear()

pool.roll()
pool.roll_dice(die)
```

## DicePool2D

```gdscript
pool_2d.setup(pool)

pool_2d.add_dice(die)
pool_2d.add_dice_multiple(dice)

pool_2d.remove_dice(die)
pool_2d.clear()

pool_2d.roll()

pool_2d.select_dice(die)
pool_2d.deselect_dice(die)
pool_2d.clear_selection()

pool_2d.get_dice()
pool_2d.get_dice_visual(die)
pool_2d.get_selected_dice()
```

---

# Typical Workflow

For most games, the workflow is:

```text
1. Create DiceResource assets
          ↓
2. Create runtime Dice objects
          ↓
3. Put them into a DicePool if needed
          ↓
4. Create Dice2D / DicePool2D
          ↓
5. Add the visual nodes to your scene
          ↓
6. Roll through the appropriate API
          ↓
7. Listen to signals
          ↓
8. Interpret the symbols in your game
```

The important thing is that **the game does not need to know how the dice are visually constructed**.

It only needs to know:

> "I have a die. I rolled it. What symbols did I get?"

or:

> "I have a pool of dice. They rolled. What did the pool produce?"

That is the primary interface provided by the Dice Symbols Engine.