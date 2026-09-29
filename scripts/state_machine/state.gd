class_name State
extends Node
## One behaviour of a StateMachine. Emit `finished` with the name of a sibling state to transition.

@warning_ignore("unused_signal")
signal finished(next_state: StringName, data: Dictionary)


## Called when the machine switches to this state.
func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	pass


## Called right before the machine leaves this state.
func exit() -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
