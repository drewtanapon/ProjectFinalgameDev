extends Node3D

@onready var animation_tree = %AnimationTree
@onready var animation_player = %AnimationPlayer

func hurt():
	animation_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
func die():
	animation_player.speed_scale = 1.75
	animation_player.play("Death_B")
