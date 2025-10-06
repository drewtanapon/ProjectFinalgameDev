extends Node3D

var player_score = 0
signal enemy_died
var enemies_killed = 0
@onready var label := $Player/Camera3D/Label

func _ready():
	print("Hello from scene3!")
	# ใส่โค้ดเริ่มต้นอื่นๆ ของด่าน 3 ที่นี่
	pass

func increase_score():
	print("Hello from scene3!")
	player_score += 1
	label.text = "Score: " + str(player_score)
	if player_score >= 100:
		get_tree().change_scene_to_file("res://scene/scene3.tscn")

func _on_kill_plane_body_entered(body):
	$Player._on_player_dead()

func _on_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		enemies_killed += 1
		increase_score()
		do_poof(mob.global_position)
	)
	do_poof(mob.global_position)


func do_poof(mob_position):
	const SMOKE_PUFF = preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof := SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_position
