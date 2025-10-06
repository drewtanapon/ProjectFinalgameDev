extends Node3D

@onready var label := $Player/Camera3D/Label

# ===== ตั้งค่าจำนวนที่ต้องฆ่า =====
@export var required_kills: int = 25     # จำนวนมอนที่ต้องฆ่า
var remaining_kills: int                 # จะนับจาก required_kills ลงมา
var level_cleared: bool = false        # กันเปลี่ยนฉากซ้ำ/นับเกิน

func _ready() -> void:
	remaining_kills = max(required_kills, 0)
	_update_kill_ui()  # แสดงจำนวนที่ต้องฆ่าเริ่มต้น
	
# เรียกเมื่อ "มอนตัวหนึ่งตายจริง ๆ"
func register_kill() -> void:
	if level_cleared: 
		return
	if remaining_kills <= 0:
		return

	remaining_kills -= 1
	_update_kill_ui()

	if remaining_kills == 0:
		level_cleared = true
		# เลื่อนเปลี่ยนฉากเป็นคิวถัดไป กันปัญหาซิกแนลซ้อน
		call_deferred("_goto_next_scene")
# อัปเดตข้อความบนจอ
func _update_kill_ui() -> void:
	# ตัวอย่างข้อความ: "เหลืออีก 17 ตัว"
	label.text = "Kills Left : %d " % remaining_kills

func _goto_next_scene() -> void:
	get_tree().change_scene_to_file("res://scene/scene1.tscn")

func _on_kill_plane_body_entered(body):
	$Player._on_player_dead()


# ตอนสปอว์นมอน: ต่อสัญญาณ 'died' แบบ one-shot กันยิงซ้ำ
func _on_mob_spawner_3d_mob_spawned(mob) -> void:
	mob.died.connect(func():
		# ฟังก์ชันนี้จะถูกรันแค่ครั้งเดียวต่อมอนตัวนั้น
		register_kill()
		do_poof(mob.global_position)
	, Object.CONNECT_ONE_SHOT)

	# ควันตอนเกิด (ถ้าต้องการ)
	do_poof(mob.global_position)


func do_poof(mob_position):
	const SMOKE_PUFF = preload("res://mob/smoke_puff/smoke_puff.tscn")
	var poof := SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_position
	
	
	
