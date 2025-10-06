extends CharacterBody3D

@export var knockback_speed: float = 50.0   # ความแรงผลักถอยหลัง (ระนาบพื้น)
@export var knockback_up: float    = 3   # ให้เด้งขึ้นเล็กน้อย
@export var knockback_stun: float  = 0.20  # เวลามึน/ปิดคอนโทรล (วินาที)

var _stun_until := 0.0

@export var max_health: int = 100
var health: int = max_health
var is_dead: bool = false

@export var health_bar_path: NodePath
@onready var _health_bar := (
	get_node_or_null(health_bar_path) if health_bar_path != NodePath("")
	else %HealthBar
)

# ตายแล้วให้รีเซ็ตฉากอัตโนมัติ
@export var auto_reload_on_death: bool = true
@export var death_reload_delay: float = 0.6   # วินาทีก่อนรีโหลด

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	%Marker3D.rotation_degrees.y += 2.0
	_update_health_ui()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.5
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(
			%Camera3D.rotation_degrees.x, -60.0, 60.0
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta):
	var now := Time.get_ticks_msec() / 1000.0
	var stunned := now < _stun_until
	const SPEED = 2.5

	var input_direction_2D = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	
	var input_direction_3D = Vector3(
		input_direction_2D.x, 0, input_direction_2D.y
	)
	var direction = transform.basis * input_direction_3D

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	velocity.y -= 20.0 * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 10.0
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()

	# 🔥 ส่วนควบคุมแอนิเมชัน
	if direction.length() > 0.1 and is_on_floor():
		if $"character-g2/AnimationPlayer".current_animation != "walk":
			$"character-g2/AnimationPlayer".play("walk")
	else:
		if $"character-g2/AnimationPlayer".current_animation != "idle":
			$"character-g2/AnimationPlayer".play("RESET")

	# 🔫 ยิงกระสุน
	if Input.is_action_pressed("shoot") and %Timer.is_stopped():
		shoot_bullet()
		
	if stunned:
		# ดับแรงถอยลงเรื่อย ๆ ระหว่างสตัน (ค่า 20 ปรับได้)
		var h := Vector3(velocity.x, 0.0, velocity.z)
		h = h.move_toward(Vector3.ZERO, 20.0 * delta)
		velocity.x = h.x
		velocity.z = h.z
	else:
		# >>> โค้ดควบคุมการเดินปกติของคุณ ให้อยู่ในบล็อกนี้เท่านั้น <<<
		# ตั้ง velocity.x / velocity.z ที่นี่ตามอินพุต
		pass

	# แรงโน้มถ่วงปกติ
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	move_and_slide()


func shoot_bullet():
	const BULLET_3D = preload("bullet_3d.tscn")
	var new_bullet = BULLET_3D.instantiate()
	%Marker3D.add_child(new_bullet)

	new_bullet.global_transform = %Marker3D.global_transform

	%Timer.start()
	%AudioStreamPlayer.play()

func take_damage_by_ratio(ratio: float, from_world_pos: Vector3 = global_transform.origin) -> void:
	if is_dead: return
	var amount := int(round(max_health * ratio))
	take_damage(amount, from_world_pos)

func take_damage(amount: int, from_world_pos: Vector3 = global_transform.origin) -> void:
	if is_dead: return
	_set_health(health - amount)
	apply_knockback(from_world_pos)
	var prev := health
	health = clamp(health - amount, 0, max_health)
	print("[PLAYER] DMG from=", from_world_pos, " -", amount, "  HP:", prev, "->", health)

func heal(amount: int) -> void:
	_set_health(health + amount)

func _set_health(value: int) -> void:
	var prev := health
	health = clamp(value, 0, max_health)
	if health != prev:
		_update_health_ui()
	if health <= 0 and not is_dead:
		_on_player_dead()

func _update_health_ui() -> void:
	if _health_bar:
		# ทั้ง ProgressBar และ TextureProgressBar สืบทอดจาก Range (มี max_value/value)
		_health_bar.max_value = max_health
		_health_bar.value = health

func _on_player_dead() -> void:
	is_dead = true
	# (ทางเลือก) ปิดการควบคุม/ฟิสิกส์ชั่วคราว
	set_physics_process(false)
	set_process(false)

	# TODO: เล่นอนิเมชัน/เสียงตายได้ตรงนี้ ถ้ามี
	# await $Anim.play("die")

	if auto_reload_on_death:
		await get_tree().create_timer(death_reload_delay).timeout
		get_tree().reload_current_scene()
		
func apply_knockback(from_world_pos: Vector3, power: float = knockback_speed, up: float = knockback_up) -> void:
	# ทิศจากผู้โจมตี -> ผู้เล่น (ถอยหลัง = หนีออก)
	var dir := (global_transform.origin - from_world_pos)
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
	# ตั้งความเร็วถอยทันที
	velocity = dir * power + Vector3.UP * up
	_stun_until = Time.get_ticks_msec() / 1000.0 + knockback_stun
