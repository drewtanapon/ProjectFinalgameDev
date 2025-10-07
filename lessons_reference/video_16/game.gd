extends Node3D

@onready var label: Label = $Player/Camera3D/Label
@onready var labelC: Label = $Player/Camera3D/LabelC

# ===== ตั้งค่าจำนวนที่ต้องฆ่า =====
@export var required_kills: int = 25
var remaining_kills: int
var level_cleared: bool = false

# ===== ตั้งค่าการเคลียร์ด่าน =====
@export var next_scene_path: String = "res://scene/scene1.tscn"
@export var mob_group_name: String = "Mob"              # ให้มอนทุกตัวอยู่ในกลุ่มนี้
@export var spawner_group_name: String = "MobSpawner"   # ให้สปอว์นเนอร์ทุกตัวอยู่ในกลุ่มนี้
@export var clear_wait_seconds: float = 5.0             # หยุด 5 วิก่อนเปลี่ยนฉาก

func _ready() -> void:
	remaining_kills = max(required_kills, 0)
	_update_kill_ui()

# เรียกเมื่อ "มอนตายจริง ๆ"
func register_kill() -> void:
	if level_cleared or remaining_kills <= 0:
		return

	remaining_kills -= 1
	_update_kill_ui()

	if remaining_kills == 0:
		level_cleared = true
		call_deferred("_on_level_cleared")  # กันสัญญาณซ้อน

func _update_kill_ui() -> void:
	label.text = "%d" % remaining_kills

func _on_level_cleared() -> void:
	# 1) หยุดสปอว์นเนอร์ทั้งหมดทันที
	_pause_all_spawners(true)

	# 2) ฆ่ามอนที่เหลือทั้งหมด (ไม่นับเพิ่ม เพราะ level_cleared = true แล้ว)
	_kill_all_remaining_mobs()

	# 3) แสดงข้อความผ่านด่าน
	if labelC:
		labelC.text = "Stage Clear!"
		# ถ้าอยากใส่เอฟเฟกต์เล็กน้อย: (ปล่อยไว้ก็ได้)
		# label.modulate = Color(0.8, 1.0, 0.8)

	# 4) รอ 5 วินาทีแล้วค่อยเปลี่ยนฉาก
	await get_tree().create_timer(clear_wait_seconds).timeout
	get_tree().change_scene_to_file(next_scene_path)

func _kill_all_remaining_mobs() -> void:
	var mobs: Array[Node] = get_tree().get_nodes_in_group(mob_group_name)
	for m: Node in mobs:
		# เผื่อมีมอนเพิ่งสปอว์นระหว่างเคลียร์
		if not is_instance_valid(m):
			continue
		# ถ้ามีเมธอด die() ให้เรียก จะได้ยิงสัญญาณ/เอฟเฟกต์ตายของมันเอง
		if m.has_method("die"):
			m.call("die")
		else:
			m.queue_free()

func _pause_all_spawners(paused: bool) -> void:
	var spawners: Array[Node] = get_tree().get_nodes_in_group(spawner_group_name)
	for s: Node in spawners:
		if not is_instance_valid(s):
			continue
		# กรณีสปอว์นเนอร์มี API เฉพาะ
		if s.has_method("set_active"):
			s.call("set_active", not paused)
		elif s.has_method("pause_spawning"):
			s.call("pause_spawning", paused)
		elif "active" in s:
			s.set("active", not paused)

		# กันเหนียว ปิด process ทุกโหมด
		if s.has_method("set_process"):
			s.set_process(not paused)
		if s.has_method("set_physics_process"):
			s.set_physics_process(not paused)

func _goto_next_scene() -> void:
	get_tree().change_scene_to_file(next_scene_path)

func _on_kill_plane_body_entered(body: Node) -> void:
	$Player._on_player_dead()

# ตอนสปอว์นมอน: ต่อสัญญาณ 'died' แบบ one-shot กันยิงซ้ำ
func _on_mob_spawner_3d_mob_spawned(mob: Node) -> void:
	# ถ้าด่านเคลียร์แล้ว เพิ่งสปอว์นมา ให้กำจัดทิ้งเลย
	if level_cleared:
		do_poof(mob.global_position)
		mob.queue_free()
		return

	# ต่อสัญญาณแบบปลอดภัย (รองรับมอนบางชนิดที่อาจไม่มี signal died)
	if mob.has_signal("died"):
		var pos: Vector3 = mob.global_position
		mob.died.connect(func():
			register_kill()
			do_poof(pos)
		, Object.CONNECT_ONE_SHOT)
	else:
		# ฟอลแบ็ก: ใช้ tree_exiting เป็นสัญญาณตาย
		var pos2: Vector3 = mob.global_position
		mob.tree_exiting.connect(func():
			register_kill()
			do_poof(pos2)
		, Object.CONNECT_ONE_SHOT)

	# ควันตอนเกิด (ถ้าต้องการ)
	do_poof(mob.global_position)

func do_poof(mob_position: Vector3) -> void:
	const SMOKE_PUFF := preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof: Node3D = SMOKE_PUFF.instantiate() as Node3D
	add_child(poof)
	poof.global_position = mob_position
