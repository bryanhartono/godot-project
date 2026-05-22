extends Node

const SAVE_PATH: String = "user://save.cfg"

var coins: int = 0
var unlocked_characters: Array[int] = [0, 1, 2]
var permanent_upgrades: Dictionary = {}

func _ready() -> void:
	load_data()

func save_data() -> void:
	var config = ConfigFile.new()
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "unlocked_characters", unlocked_characters)
	config.set_value("progress", "permanent_upgrades", permanent_upgrades)
	config.save(SAVE_PATH)

func load_data() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	coins = config.get_value("progress", "coins", 0)
	var loaded_chars: Array = config.get_value("progress", "unlocked_characters", [0, 1, 2])
	unlocked_characters.assign(loaded_chars)
	permanent_upgrades = config.get_value("progress", "permanent_upgrades", {})

func add_coins(amount: int) -> void:
	coins += amount
	save_data()

func unlock_character(index: int) -> void:
	if index not in unlocked_characters:
		unlocked_characters.append(index)
		save_data()
