extends CanvasLayer

@onready var result_label: Label = $CenterContainer/Panel/VBox/ResultLabel
@onready var floor_label: Label = $CenterContainer/Panel/VBox/FloorLabel
@onready var kills_label: Label = $CenterContainer/Panel/VBox/KillsLabel

func setup(won: bool, floor_num: int, kills: int) -> void:
	if won:
		result_label.text = "VICTORY"
		result_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.65, 1))
	else:
		result_label.text = "DEFEATED"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.18, 1))
	floor_label.text = "Floor Reached:  %d" % floor_num
	kills_label.text = "Enemies Defeated:  %d" % kills

func _on_play_again_pressed() -> void:
	AudioManager.play("ui_click", -6.0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_main_menu_pressed() -> void:
	AudioManager.play("ui_click", -6.0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
