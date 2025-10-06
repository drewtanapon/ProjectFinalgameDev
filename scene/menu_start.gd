extends Control

func _ready():
	# เชื่อมสัญญาณของปุ่ม
	$VBoxContainer/Button.pressed.connect(_on_play_pressed)
	$VBoxContainer/Button2.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	# เมื่อกดปุ่ม PLAY ให้เปลี่ยนฉากไปยังหน้าเกม
	get_tree().change_scene_to_file("res://scene/game.tscn")

func _on_quit_pressed():
	# เมื่อกดปุ่ม QUIT ให้ปิดเกม
	get_tree().quit()
