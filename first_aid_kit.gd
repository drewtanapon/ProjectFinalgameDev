extends Node3D

@export var respawn_time: float = 30.0
@export var idle_anim_name: String = "Idle"
@export var pickup_fx_path: NodePath
@export var player_layer_index: int = 2

@export var visuals_path: NodePath = ^"Pivot"
@export var pickup_area_path: NodePath = ^"PickupArea"
@export var animation_player_path: NodePath = ^"AnimationPlayer"

@onready var _visuals: Node3D = get_node_or_null(visuals_path) as Node3D
@onready var _area: Area3D = get_node_or_null(pickup_area_path) as Area3D
@onready var _anim: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer
@onready var _pickup_fx: AudioStreamPlayer3D = (get_node_or_null(pickup_fx_path) as AudioStreamPlayer3D) if pickup_fx_path != NodePath("") else null

var _is_available := true
var _poll_timer: Timer

func _ready() -> void:
	# เคสสคริปต์ติดผิดอินสแตนซ์: ชื่อไม่ตรง/ไม่ได้ติดกับฉากที่ใช้งาน
	if get_parent() == null:
		push_warning("[FirstAidKit] ⚠ parent == null (อาจเปิดจากแยกฉาก)")
	self.process_mode = Node.PROCESS_MODE_ALWAYS

	# ตั้งอนิเมชัน (ถ้ามี)
	if _anim and idle_anim_name != "":
		var a := _anim.get_animation(idle_anim_name)
		if a: a.loop_mode = Animation.LOOP_LINEAR
		_anim.play(idle_anim_name)
		_anim.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		print("[FirstAidKit] (info) ไม่มี AnimationPlayer หรือ idle_anim_name ว่าง")

	# หา Area ให้เจอแม้ path คลาด
	if _area == null:
		_area = find_child("PickupArea", true, false) as Area3D
	if _area == null:
		# เผื่อใช้ชื่ออื่น
		for c in get_children():
			if c is Area3D:
				_area = c
				break
	if _area == null:
		push_error("[FirstAidKit] ❌ ไม่พบ Area3D เลย (ตั้งชื่อ 'PickupArea' หรือแก้ pickup_area_path)")
		return

	# ตรวจว่ามี CollisionShape3D จริงไหม
	var has_shape := _has_shape_recursive(_area)
	if not has_shape:
		push_error("[FirstAidKit] ❌ PickupArea ไม่มี CollisionShape3D/shape ว่างหรือเล็กเกิน")

	# เปิด monitoring + ตั้ง mask ให้เห็นชั้นของ Player
	_area.monitoring = true
	_area.monitorable = true
	for i in range(1, 33):
		_area.set_collision_mask_value(i, false)
	_area.set_collision_mask_value(player_layer_index, true)

	# ต่อสัญญาณทั้ง body_entered/area_entered เพื่อดูว่ามันยิงไหม
	if not _area.body_entered.is_connected(_on_area_body_entered):
		_area.body_entered.connect(_on_area_body_entered)
	if not _area.area_entered.is_connected(_on_area_area_entered):
		_area.area_entered.connect(_on_area_area_entered)

	# ตั้งโพลทุก 0.5 วินาที รายงานสิ่งที่ทับซ้อน (ช่วยรู้ว่าผู้เล่นชนจริงไหม)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.autostart = true
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll_tick)
	add_child(_poll_timer)

	# รายงานซ้ำหลัง 1 เฟรม (ให้ฟิสิกส์อัปเดต)
	await get_tree().process_frame
	_poll_tick()

func _has_shape_recursive(n: Node) -> bool:
	if n is CollisionShape3D:
		var cs := n as CollisionShape3D
		return cs.shape != null
	for c in n.get_children():
		if _has_shape_recursive(c):
			return true
	return false

func _poll_tick() -> void:
	if _area == null:
		return
	var bodies := _area.get_overlapping_bodies()
	var areas := _area.get_overlapping_areas()

func _on_area_body_entered(body: Node) -> void:
	if not _is_available:
		return

	# ตรวจว่าเป็นผู้เล่นไหม (หนึ่งในสามอย่างนี้ผ่านก็พอ)
	var is_player := (
		body.is_in_group("Player")
		or body.has_method("heal_to_full")
		or body.has_method("take_damage_by_ratio")
	)
	if not is_player:
		print("[FirstAidKit] ⚠ ไม่ใช่ Player, ข้าม")
		return

	_pick_and_heal(body)

func _on_area_area_entered(area: Area3D) -> void:
	print("[FirstAidKit] SIGNAL area_entered ->", area.name)

func _pick_and_heal(who: Node) -> void:
	_heal_player_full(who)
	_on_picked()

func _heal_player_full(player: Node) -> void:
	if player.has_method("heal_to_full"):
		player.heal_to_full()
	else:
		var mh = player.get("max_health")
		if typeof(mh) == TYPE_INT or typeof(mh) == TYPE_FLOAT:
			player.set("health", int(mh))
			if player.has_method("_update_health_ui"):
				player._update_health_ui()

func _on_picked() -> void:
	_is_available = false
	if _pickup_fx:
		_pickup_fx.play()
	if _area:
		_area.monitoring = false
	if _visuals:
		_visuals.visible = false
	_set_area_enabled(false)   # ปิดการชน
	_set_visible_recursive(self, false)  # ⟵ ซ่อนทั้งกิ่ง (ชัวร์สุด
	await get_tree().create_timer(respawn_time).timeout
	_respawn()
	

func _respawn() -> void:
	_is_available = true
	_set_visible_recursive(self, true)    # โชว์กลับทั้งกิ่ง
	_set_area_enabled(true)               # เปิด Area กลับมา
	if _visuals:
		_visuals.visible = true
	if _area:
		_area.monitoring = true
	if _anim and idle_anim_name != "":
		_anim.play(idle_anim_name)

func _layer_bits(body: Object) -> Array:
	var bits: Array = []
	if "collision_layer" in body:
		var v := int(body.get("collision_layer"))
		for i in range(1, 33):
			if (v & (1 << (i - 1))) != 0:
				bits.append(i)
	return bits

# ===== helpers =====
func _set_area_enabled(enabled: bool) -> void:
	if _area:
		_area.monitoring = enabled
		# เผื่อมี CollisionShape หลายอันใต้ Area ให้ปิดด้วย
		for c in _area.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = not enabled

func _set_visible_recursive(n: Node, vis: bool) -> void:
	# ซ่อน/โชว์ทุก VisualInstance3D (MeshInstance3D, GPUParticles3D, ฯลฯ) และ Node3D ที่มี property visible
	if "visible" in n:
		n.set("visible", vis)
	for child in n.get_children():
		_set_visible_recursive(child, vis)
