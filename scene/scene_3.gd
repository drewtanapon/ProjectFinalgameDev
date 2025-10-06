extends Node3D

# ===== เป้าหมายต่อด่าน =====
@export var required_kills: int = 100   # จำนวนที่ต้องกำจัดทั้งหมด
var remaining_kills: int                # นับถอยหลังจาก required_kills
var level_cleared: bool = false         # กันเปลี่ยนฉากซ้ำ/นับเกิน

# ===== UI =====
@onready var label := $Player/Camera3D/Label

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
	}, Object.CONNECT_ONE_SHOT)

	# ควันตอนเกิด (ถ้าต้องการ)
	do_poof(mob.global_position)

func do_poof(mob_position: Vector3) -> void:
	const SMOKE_PUFF = preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof := SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_position
