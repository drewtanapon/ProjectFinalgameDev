extends Node3D

# ===== เป้าหมายต่อด่าน =====
@export var required_kills: int = 50
var remaining_kills: int
var level_cleared: bool = false

# ===== UI & การเปลี่ยนฉาก =====
@onready var label: Label = $Player/Camera3D/Label
@onready var labelC: Label = $Player/Camera3D/LabelC
@export var next_scene_path: String = "res://scene/scene3.tscn"

# ===== กลุ่มมอน/สปอว์นเนอร์ & เวลาหน่วงตอนเคลียร์ =====
@export var mob_group_name: String = "Mob"
@export var spawner_group_name: String = "MobSpawner"
@export var clear_wait_seconds: float = 5.0

func _ready() -> void:
	print("Hello from scene3!")
	remaining_kills = max(required_kills, 0)
	_update_kill_ui()

# เรียกเมื่อมอน "ตายจริง ๆ"
func register_kill() -> void:
	if level_cleared or remaining_kills <= 0:
		return
	remaining_kills -= 1
	_update_kill_ui()
	if remaining_kills == 0:
		level_cleared = true
		call_deferred("_on_level_cleared")

func _update_kill_ui() -> void:
	label.text = "%d" % remaining_kills
	# หรือแบบ: label.text = "Kills: %d / %d" % [required_kills - remaining_kills, required_kills]

func _on_level_cleared() -> void:
	# 1) หยุดสปอว์นเนอร์ทั้งหมด
	_pause_all_spawners(true)
	# 2) ฆ่ามอนที่เหลือทั้งหมด (จะไม่เพิ่มตัวนับเพราะ level_cleared = true แล้ว)
	_kill_all_remaining_mobs()
	# 3) แสดงข้อความผ่านด่าน
	if labelC:
		labelC.text = "Stage Clear!"
	# 4) หน่วงก่อนเปลี่ยนฉาก
	await get_tree().create_timer(clear_wait_seconds).timeout
	get_tree().change_scene_to_file(next_scene_path)

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
		if s.has_method("set_process"):
			s.set_process(not paused)
		if s.has_method("set_physics_process"):
			s.set_physics_process(not paused)

func _on_kill_plane_body_entered(body) -> void:
	$Player._on_player_dead()

# ตอนสปอว์นมอน: ต่อสัญญาณ 'died' แบบ one-shot กันนับซ้ำ
func _on_mob_spawner_3d_mob_spawned(mob: Node) -> void:
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

	do_poof(mob.global_position)

func do_poof(mob_position: Vector3) -> void:
	const SMOKE_PUFF := preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof: Node3D = SMOKE_PUFF.instantiate() as Node3D
	add_child(poof)
	poof.global_position = mob_position
