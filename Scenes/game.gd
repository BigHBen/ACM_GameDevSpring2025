extends Node
class_name  GameManager

signal _on_game_paused(is_paused : bool)

var game_paused : bool = false :
	set(val):
		game_paused = val
		get_tree().paused = game_paused
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

func _ready() -> void:
	print("hello")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		game_paused = !game_paused
