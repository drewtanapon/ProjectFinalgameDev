extends Node

# Reference UI
@export var label: Label
@export var scene_holder: Node  # Node เปล่าสำหรับโหลด scene

# List ของแต่ละด่าน
var scenes = [
	"res://scene/game.tscn",
	"res://scene/scene1.tscn",
    "res://scene/scene3.tscn"
]

var current_index = 0
var enemies_to_kill = 50
var enemies_killed = 0
var current_scene: Node = null
var game_node

func _ready():
	print("SceneHolder:", scene_holder)
	print("Loading scene:", scenes[current_index])
	load_scene(scenes[current_index])
	print("Current scene:", current_scene)
	#show_message("LEVEL 1 START!")
	#load_scene(scenes[current_index])

# --- แสดงข้อความที่ Label ---
func show_message(text: String):
	if not label:
		return
	label.text = text
	label.show()
	label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)

# --- โหลด Scene ---
func load_scene(scene_path: String):
	# ลบ Scene เก่า
	if scene_holder == null:
		push_error("SceneHolder is null! Cannot load scene.")
		return
		
	for child in scene_holder.get_children():
		child.queue_free()

	# โหลด Scene ใหม่
	var scene = load(scene_path).instantiate()
	scene_holder.add_child(scene)
	current_scene = scene

	enemies_killed = 0

	# เชื่อม signal "died" จากศัตรูทุกตัว
	for child in current_scene.get_children():
		if child.has_signal("died"):
			child.connect("died", Callable(self, "_on_enemy_died"))

# --- เมื่อศัตรูตาย ---
func _on_enemy_died():
	enemies_killed += 1
	update_score()
	if enemies_killed >= enemies_to_kill:
		level_complete()

func update_score():
	if label:
		label.text = "Score: %d / %d" % [enemies_killed, enemies_to_kill]

# --- เมื่อจบ Level ---
func level_complete():
	show_message("LEVEL COMPLETE!")
	await get_tree().create_timer(2.0).timeout
	next_scene()

# --- ไป Scene ถัดไป ---
func next_scene():
	current_index += 1
	if current_index < scenes.size():
		show_message("LEVEL %d START!" % (current_index + 1))
		await get_tree().create_timer(1.5).timeout
		load_scene(scenes[current_index])
	else:
		show_message("🎉 YOU WIN! 🎉")
