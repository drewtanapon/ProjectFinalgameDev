extends CharacterBody3D

@export var move_speed: float = 5.5
@export var gravity: float = 20.0
@export var jump_speed: float = 10.0
@export var reload_scene_delay: float = 0.6

signal died
var _alive := true

func _ready() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if has_node("HurtBox"):
		$HurtBox.body_entered.connect(_on_hurtbox_body_entered)
		$HurtBox.area_entered.connect(_on_hurtbox_area_entered)  # เผื่อศัตรูใช้ Area3D
	else:
		push_warning("ไม่พบโหนด HurtBox (Area3D) ใต้ Player — โปรดสร้าง Area3D+CollisionShape3D แล้วตั้งชื่อ HurtBox")

func _unhandled_input(event: InputEvent) -> void:
	if not _alive: return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.5
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -60.0, 60.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not _alive: return

	var input2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input3d := Vector3(input2d.x, 0.0, input2d.y)
	var dir := transform.basis * input3d

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()

	if Input.is_action_pressed("shoot") and %Timer.is_stopped():
		shoot_bullet()

func shoot_bullet() -> void:
	const BULLET_3D = preload("res://bullet_3d.tscn") # ใส่ res:// ให้ชัวร์
	var b := BULLET_3D.instantiate()
	%Marker3D.add_child(b)
	b.global_transform = %Marker3D.global_transform
	%Timer.start()

# ---------- ชนแล้วตาย ----------
func _on_hurtbox_body_entered(body: Node) -> void:
	if body.is_in_group("Mob"):
		die()

func _on_hurtbox_area_entered(area: Area3D) -> void:
	# กรณีศัตรูใช้ Area3D เป็น HitBox
	if area.is_in_group("Mob") or (area.get_parent() and area.get_parent().is_in_group("Mob")):
		die()

func die() -> void:
	if not _alive: return
	_alive = false

	# หยุดทุกอย่าง
	set_physics_process(false)
	set_process_unhandled_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	velocity = Vector3.ZERO
	if has_node("%Timer"):
		%Timer.stop()

	emit_signal("died")

	await get_tree().create_timer(reload_scene_delay).timeout
	get_tree().reload_current_scene()
