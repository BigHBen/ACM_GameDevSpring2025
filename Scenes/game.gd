extends Node
class_name  GameManager

@onready var color_rect : ColorRect = $UI/ColorRect
@onready var pause_menu : Control = $UI/PauseMenu

signal _on_game_paused(is_paused : bool)

var game_paused : bool = false :
	set(val):
		game_paused = val
		get_tree().paused = game_paused
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		game_paused = !game_paused
