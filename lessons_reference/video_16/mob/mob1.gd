extends RigidBody3D

signal died

var speed = randf_range(2.0, 4.0)
var health = 3

@onready var Mage_model = %Skeleton_Mage
@onready var timer = %Timer

@onready var player = get_tree().get_first_node_in_group("player")

@onready var hurt_sound = %HurtSound
@onready var ko_sound = %KOSound
@export var gravity_strength := 9.8

@onready var hitbox: Area3D = $"Skeleton_Mage/Hitbox"    # ใน mob.tscn ควรมีลูกเป็น Area3D ชื่อ Hitbox พร้อม CollisionShape3D
var damage_ratio := 0.33                  # 33%
var hit_cooldown := 0.5                   # กันหักรัว (วินาที)
var _last_hit_time := -999.0

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
	Mage_model.rotation.y = Vector3.FORWARD.signed_angle_to(direction, Vector3.UP) + PI

func take_damage():
	if health <= 0:
		return

	Mage_model.hurt()
	health -= 1
	hurt_sound.pitch_scale = randfn(1.0, 0.1)
	hurt_sound.play()

	if health == 0:
		ko_sound.play()
		Mage_model.animation_tree.active = false
		Mage_model.die()
		set_physics_process(false)
		gravity_scale = 1.0
		var direction = player.global_position.direction_to(global_position)
		var random_upward_force = Vector3.UP * randf() * 5.0
		apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)

		timer.start()


func _on_timer_timeout():
	queue_free()
	died.emit()

func _ready() -> void:
	if hitbox:
		# ให้ Hitbox เห็น Player (ซึ่งอยู่ Layer 2)
		hitbox.set_collision_mask_value(2, true)  # เปิด Mask ช่อง 2
		hitbox.monitoring = true
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
func _on_hitbox_body_entered(body: Node) -> void:
	if body and body.is_in_group("Player") and body.has_method("take_damage_by_ratio"):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_hit_time >= hit_cooldown:
			_last_hit_time = now
			
			var hit_from: Vector3
			if is_instance_valid(hitbox):
				hit_from = (hitbox as Node3D).global_position  # หรือ .global_transform.origin
			else:
				hit_from = global_position
			body.take_damage_by_ratio(damage_ratio, hit_from)
