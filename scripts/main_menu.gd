extends Control

func _on_play_pressed() -> void:
	AudioManager.play("ui_click", -6.0)
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play("ui_click", -6.0)
	get_tree().quit()
