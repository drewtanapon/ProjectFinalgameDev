extends Node3D

# ===== เป้าหมายต่อด่าน =====
@export var required_kills: int = 1
var remaining_kills: int
var level_cleared: bool = false

# ===== กลุ่ม/เวลา/ฉากถัดไป =====
@export var mob_group_name: String = "Mob"
@export var spawner_group_name: String = "MobSpawner"
@export var clear_wait_seconds: float = 5.0
@export var next_scene_path: String = "res://scene/scene3.tscn"

# ===== UI =====
@onready var label: Label = $Player/Camera3D/Label
@onready var white_bg: CanvasItem = $Player/white_bg
@onready var congratulations: CanvasItem = $Player/congratulations
@onready var enter: CanvasItem = $Player/enter

@onready var white_bg := $Player/white_bg
@onready var congratulations := $Player/congratulations
@onready var enter := $Player/enter
@onready var hpbar := $Player/Camera3D/HealthBar
var _scene_changed: bool = false

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
		$Player.set_physics_process(false)
		level_cleared = true
		show_congratulations()

	
		call_deferred("_on_level_cleared")

func _update_kill_ui() -> void:
	label.text = "%d" % remaining_kills
	# ถ้าอยากโชว์ข้อความประกอบ เช่น "Enemies Left: X"
	# label.text = "Enemies Left: %d" % remaining_kills

func _on_level_cleared() -> void:
	# 1) หยุดสปอว์นเนอร์ทั้งหมด
	_pause_all_spawners(true)
	# 2) ฆ่ามอนที่เหลือทั้งหมด
	_kill_all_remaining_mobs()
	# 3) แสดงฉากจอขาว + ข้อความแสดงความยินดี + Press Enter
	await show_congratulations()
	# 4) กรณียังไม่กด Enter ภายใน clear_wait_seconds ให้ไปอัตโนมัติ
	if not _scene_changed:
		await get_tree().create_timer(clear_wait_seconds).timeout
		if not _scene_changed:
			get_tree().change_scene_to_file(next_scene_path)
			_scene_changed = true

func _kill_all_remaining_mobs() -> void:
	var mobs: Array[Node] = get_tree().get_nodes_in_group(mob_group_name)
	for m in mobs:
		if not is_instance_valid(m):
			continue
		if m.has_method("die"):
			m.call("die")
		else:
			m.queue_free()

func _pause_all_spawners(paused: bool) -> void:
	var spawners: Array[Node] = get_tree().get_nodes_in_group(spawner_group_name)
	for s in spawners:
		if not is_instance_valid(s):
			continue
		if s.has_method("set_active"):
			s.call("set_active", not paused)
		elif s.has_method("pause_spawning"):
			s.call("pause_spawning", paused)
		elif "active" in s:
			s.set("active", not paused)
		# กันเหนียวปิด process
		if s.has_method("set_process"):
			s.set_process(not paused)
		if s.has_method("set_physics_process"):
			s.set_physics_process(not paused)

func _on_kill_plane_body_entered(body: Node) -> void:
	$Player._on_player_dead()

# ตอนสปอว์นมอน: ต่อสัญญาณ 'died' แบบ one-shot กันนับซ้ำ
func _on_mob_spawner_3d_mob_spawned(mob: Node) -> void:
	# ถ้าด่านเคลียร์แล้ว เพิ่งสปอว์นมา ให้กำจัดเลย
	if level_cleared:
		do_poof(mob.global_position)
		mob.queue_free()
		return

	if mob.has_signal("died"):
		var pos: Vector3 = mob.global_position
		mob.died.connect(func():
			register_kill()
			do_poof(pos)
		, Object.CONNECT_ONE_SHOT)
	else:
		var pos2: Vector3 = mob.global_position
		mob.tree_exiting.connect(func():
			register_kill()
			do_poof(pos2)
		, Object.CONNECT_ONE_SHOT)

	# ควันตอนเกิด (ถ้าต้องการ)
	do_poof(mob.global_position)

func show_congratulations() -> 
	void:hpbar.visible = false
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

func wait_for_enter() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			# ตัวอย่าง: ไปฉากใหม่ หรือรีโหลด
			get_tree().change_scene_to_file("res://lessons_reference/video_16/game.tscn")
			break

# ==== FX ====
func do_poof(mob_position: Vector3) -> void:
	const SMOKE_PUFF := preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof: Node3D = SMOKE_PUFF.instantiate() as Node3D
	add_child(poof)
	poof.global_position = mob_position
	
func wait_for_space():
	while true:
		await get_tree().create_timer(0.01).timeout
		if Input.is_action_just_pressed("ui_select"): # ปุ่ม spacebar โดยค่าเริ่มต้นของ Godot
			get_tree().change_scene_to_file("res://lessons_reference/video_16/game.tscn")
			break
