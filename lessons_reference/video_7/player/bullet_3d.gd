extends Area3D

@export var speed: float = 40.0
@export var life_time: float = 3.0

func _ready() -> void:
	# ชนอะไรแล้วให้เรียก _on_hit
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	# ตั้งเวลาลบตัวเอง กันกระสุนค้างในฉาก
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# วิ่งไปข้างหน้าแกน -Z ของตัวเอง
	global_position += -global_transform.basis.z * speed * delta

func _on_hit(_other: Node) -> void:
	# ถ้าอยากให้โดนแค่มอน ให้เช็คกรุ๊ป
	# if _other.is_in_group("Mob"): 
	#     # ทำดาเมจ ฯลฯ
	queue_free()
