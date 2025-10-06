extends RigidBody3D

signal died

var speed = randf_range(2.0, 4.0)
var health = 3

@onready var bat_model = %Skeleton_Mage
@onready var timer = %Timer

@onready var player = get_tree().get_first_node_in_group("player")

@onready var hurt_sound = %HurtSound
@onready var ko_sound = %KOSound
@export var gravity_strength := 9.8

func _physics_process(delta):
	if not player:
		return  # ป้องกัน null error
	var velocity = linear_velocity

	# ใส่แรงโน้มถ่วง
	velocity.y -= gravity_strength * delta

	# คำนวณทิศทางการเคลื่อนที่ไปยัง player (ไม่แตะแกน Y)
	var direction = global_position.direction_to(player.global_position)
	direction.y = 0.0

	# อัพเดตความเร็วในแนวราบ (X,Z) เท่านั้น
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# อัพเดตกลับไปที่ตัว rigidbody
	linear_velocity = velocity

	# หมุนโมเดลให้หันไปทางผู้เล่น
	bat_model.rotation.y = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP) + PI

func take_damage():
	if health <= 0:
		return

	bat_model.hurt()
	health -= 1
	hurt_sound.pitch_scale = randfn(1.0, 0.1)
	hurt_sound.play()

	if health == 0:
		ko_sound.play()
		bat_model.animation_tree.active = false
		bat_model.die()
		set_physics_process(false)
		gravity_scale = 1.0
		var direction = player.global_position.direction_to(global_position)
		var random_upward_force = Vector3.UP * randf() * 5.0
		apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)

		timer.start()


func _on_timer_timeout():
	queue_free()
	died.emit()
