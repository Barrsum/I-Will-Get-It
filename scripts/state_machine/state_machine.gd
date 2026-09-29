class_name StateMachine
extends Node
## Runs exactly one child State at a time. Children transition by emitting State.finished
## with the node name of the next state. Adapted from Jeh3no's Godot-Third-Person-Controller
## and GDQuest's finite state machine pattern (both MIT).

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State

var state: State


func _ready() -> void:
	for child in get_children():
		if child is State:
			(child as State).finished.connect(transition_to)
	# States reach into their owner, so wait until it is fully ready.
	if owner and not owner.is_node_ready():
		await owner.ready
	state = initial_state if initial_state else get_child(0) as State
	state.enter(&"")


func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)


func _process(delta: float) -> void:
	if state:
		state.update(delta)


func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)


func transition_to(next_state: StringName, data: Dictionary = {}) -> void:
	var target := get_node_or_null(NodePath(next_state)) as State
	if target == null:
		push_error("%s: no state named '%s'" % [owner.name, next_state])
		return
	var previous := state.name
	state.exit()
	state = target
	state.enter(previous, data)
	state_changed.emit(previous, state.name)
