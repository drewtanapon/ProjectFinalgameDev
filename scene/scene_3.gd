extends Node3D

# ===== เป้าหมายต่อด่าน =====
@export var required_kills: int = 100   # จำนวนที่ต้องกำจัดทั้งหมด
var remaining_kills: int                # นับถอยหลังจาก required_kills
var level_cleared: bool = false         # กันเปลี่ยนฉากซ้ำ/นับเกิน

# ===== UI =====
@onready var label := $Player/Camera3D/Label

@onready var white_bg := $Player/white_bg
@onready var congratulations := $Player/congratulations
@onready var enter := $Player/enter
@onready var hpbar := $Player/Camera3D/HealthBar

func _ready() -> void:
	print("Hello from scene3!")
	remaining_kills = max(required_kills, 0)
	_update_kill_ui()	
	white_bg.visible = false
	congratulations.visible = false
	enter.visible = false

# เรียกเมื่อมอน "ตายจริง ๆ"
func register_kill() -> void:
	if level_cleared or remaining_kills <= 0:
		return

	remaining_kills -= 1
	_update_kill_ui()

	if remaining_kills == 0:
		level_cleared = true
		call_deferred("_goto_next_scene")

func _goto_next_scene() -> void:
	get_tree().change_scene_to_file("res://scene/scene3.tscn")

func _update_kill_ui() -> void:
	# ตัวอย่าง HUD: Enemies Left: X
	label.text = "Enemies Left: %d" % remaining_kills
	# ถ้าอยากแสดงแบบ "Kills: N / M" แทน:
	# label.text = "Kills: %d / %d" % [required_kills - remaining_kills, required_kills]

func _on_kill_plane_body_entered(body) -> void:
	$Player._on_player_dead()

func _on_mob_spawner_3d_mob_spawned(mob) -> void:
	# ต่อสัญญาณตายแบบ one-shot เพื่อกันนับซ้ำตัวเดิม
	mob.died.connect(func():
		register_kill()
		do_poof(mob.global_position)
	, Object.CONNECT_ONE_SHOT)

	# ควันตอนเกิด (ถ้าต้องการ)
	do_poof(mob.global_position)

func show_congratulations():
	hpbar.visible = false
	white_bg.visible = true
	congratulations.visible = true
	enter.visible = true

	# ตั้งค่าเริ่มต้นให้โปร่งใส
	white_bg.modulate.a = 0.0
	congratulations.modulate.a = 0.0
	enter.modulate.a = 0.0

	# Tween ค่อยๆ แสดง
	var tween = create_tween()
	tween.tween_property(white_bg, "modulate:a", 1.0, 1.5)
	tween.parallel().tween_property(congratulations, "modulate:a", 1.0, 2.0).set_delay(0.3)
	tween.parallel().tween_property(enter, "modulate:a", 1.0, 2.0).set_delay(1.2)

	await tween.finished
	await wait_for_space()

func wait_for_enter():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			# ตัวอย่าง: ไปฉากใหม่ หรือรีโหลด
			get_tree().change_scene_to_file("res://scene/next_scene.tscn")
			break

func do_poof(mob_position: Vector3) -> void:	
	const SMOKE_PUFF = preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof := SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_position
	
func wait_for_space():
	while true:
		await get_tree().create_timer(0.01).timeout
		if Input.is_action_just_pressed("ui_select"): # ปุ่ม spacebar โดยค่าเริ่มต้นของ Godot
			get_tree().change_scene_to_file("res://scene/game.tscn")
			break
