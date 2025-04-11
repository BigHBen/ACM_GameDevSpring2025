extends Control

@export var game_manager : Node
@onready var debug_menu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	if get_tree().current_scene is GameManager: 
		debug_menu = game_manager.debug
		game_manager._on_player_defeat.connect(_on_game_defeat_ui)
	if get_tree().current_scene is GameManagerMultiplayer: 
		debug_menu = game_manager.debug
		game_manager._on_player_defeat.connect(_on_game_defeat_ui)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func tween_shader_property(param:String,target_value: float, duration: float):
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property($"../ColorRect", "material:shader_parameter/"+param, target_value, duration)
	await tween.finished

func tween_self_property(param:String,target_value, duration: float):
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self,param, target_value, duration)
	await tween.finished

func _on_game_defeat_ui(node_info : Array):
	if node_info.size() > 1 and node_info[1]: 
		if game_manager:
			for player in game_manager.players:
				if player and player.p_inv_controller.inventory.window.visible: 
					player.p_inv_controller.inventory.window.visible = false
		
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		self.modulate = Color(1,1,1,0)
		show()
		tween_self_property("modulate",Color(1,1,1,1), 1.0)
		tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		
	else: 
		hide()
		tween_shader_property("lod",0.0, 0.25)
