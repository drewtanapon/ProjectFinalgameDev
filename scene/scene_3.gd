extends Node3D

var player_score = 0
signal enemy_died
var enemies_killed = 0
@onready var label := $Player/Camera3D/Label

@onready var white_bg := $Player/white_bg
@onready var congratulations := $Player/congratulations
@onready var enter := $Player/enter

func _ready():
	print("Hello from scene3!")
	white_bg.visible = false
	congratulations.visible = false
	enter.visible = false
	pass

func increase_score():
	print("Hello from scene3!")
	player_score += 1
	label.text = "Score: " + str(player_score)
	if player_score >= 1:
		show_congratulations()

func _on_kill_plane_body_entered(body):
	$Player._on_player_dead()

func _on_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		enemies_killed += 1
		increase_score()
		do_poof(mob.global_position)
	)
	do_poof(mob.global_position)

func show_congratulations():
	var bg = $Player/white_bg
	var congrats = $Player/congratulations
	var enter = $Player/enter

	# ทำให้ทุกอย่างมองเห็น
	bg.visible = true
	congrats.visible = true
	enter.visible = true

	# ตั้งค่าเริ่มโปร่งใส
	bg.modulate.a = 0.0
	congrats.modulate.a = 0.0
	enter.modulate.a = 0.0

	# ใช้ Tween ทำให้ค่อยๆ เลือนขึ้น
	var tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 1.5) # พื้นหลังเลือนขึ้น
	tween.parallel().tween_property(congrats, "modulate:a", 1.0, 2.0).set_delay(0.3)
	tween.parallel().tween_property(enter, "modulate:a", 1.0, 2.0).set_delay(1.2)

	# (ทางเลือก) รอให้ผู้เล่นกด Enter เพื่อไปต่อ
	await tween.finished
	await wait_for_enter()

func wait_for_enter():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			# ตัวอย่าง: ไปฉากใหม่ หรือรีโหลด
			get_tree().change_scene_to_file("res://scene/next_scene.tscn")
			break

func do_poof(mob_position):
	const SMOKE_PUFF = preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof := SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_position
