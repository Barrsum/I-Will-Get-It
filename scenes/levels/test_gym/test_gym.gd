extends Node3D
## Movement test gym. Respawns the hero if they fall out of the world.

const KILL_HEIGHT := -25.0

@onready var hero: Hero = $Hero


func _physics_process(_delta: float) -> void:
	if hero.global_position.y < KILL_HEIGHT:
		hero.respawn()
