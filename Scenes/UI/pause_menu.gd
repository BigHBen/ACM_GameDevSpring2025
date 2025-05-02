extends Control

@export var game_manager : Node
@onready var debug_menu
#@onready var inventory_menu = get_node("/root/PlayerInventory") # Now located in player scenes
@onready var resume_button = $VBoxContainer/ResumeButton
@onready var exit_button = $VBoxContainer/ExitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if game_manager is GameManager:
		debug_menu = game_manager.debug
		game_manager._on_game_paused.connect(_on_game_paused)
		resume_button.pressed.connect(_on_resume_button_pressed)
		exit_button.pressed.connect(_on_exit_button_pressed)
	elif game_manager is GameManagerMultiplayer:
		debug_menu = game_manager.debug
		game_manager._on_game_paused.connect(_on_game_paused)
		resume_button.pressed.connect(_on_resume_button_pressed)
		exit_button.pressed.connect(_on_exit_button_pressed)
	else:
		if get_tree().current_scene is GameManager: 
			debug_menu = game_manager.debug
			game_manager._on_game_paused.connect(_on_game_paused)
			resume_button.pressed.connect(_on_resume_button_pressed)
			exit_button.pressed.connect(_on_exit_button_pressed)
		if get_tree().current_scene is GameManagerMultiplayer: 
			debug_menu = game_manager.debug
			game_manager._on_game_paused.connect(_on_game_paused)
			resume_button.pressed.connect(_on_resume_button_pressed)
			exit_button.pressed.connect(_on_exit_button_pressed)
	hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# For debugging - Follow shader paramater value as it changes
	if $VBoxContainer/HSlider.visible:
		var blur_strength = $"../ColorRect".material.get_shader_parameter("lod")
		var param_range : Array = slider_test($"../ColorRect".material,"lod")
		$VBoxContainer/HSlider.max_value = int(param_range[1])
		$VBoxContainer/HSlider.value = blur_strength

func slider_test(mat,param_name):
	var properties=mat.get_property_list()
	var the_hint_range:String
	for i in range (properties.size()):
		if properties[i].name == "shader_parameter/"+param_name:
			the_hint_range=properties[i].hint_string
			break
	return the_hint_range.split(",")

func tween_shader_property(param:String,target_value: float, duration: float):
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property($"../ColorRect", "material:shader_parameter/"+param, target_value, duration)

func _on_game_paused(is_paused):
	if game_manager is GameManager: # Only pause game in single-player
		set_process(is_paused)
	if is_paused: 
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		resume_button.grab_focus()
		
		# Close inventory if open
		if game_manager:
			for player in game_manager.players:
				if player and player.p_inv_controller.inventory.window.visible: 
					player.p_inv_controller.inventory.window.visible = false
	else: 
		hide()
		tween_shader_property("lod",0.0, 0.25)
		
		# Turn on level UI (Dialog boxes and such)
		#if game_manager.get_child(0).is_in_group("Level"):
			#var level =  game_manager.get_child(0)
			#level.group_toggle_ui("NPC",true)

func _on_resume_button_pressed() -> void:
	get_tree().current_scene.game_paused = false

func _on_exit_button_pressed() -> void:
	if game_manager:
		#get_tree().paused = true
		if game_manager is GameManagerMultiplayer: 
			var player = game_manager.find_player(str(multiplayer.get_unique_id()))
			if player: 
				player.set_process(false)
				player.set_physics_process(false)
			#MultiplayerLobby._on_player_disconnected(multiplayer.get_unique_id())
		game_manager.switch_to_main_menu()
