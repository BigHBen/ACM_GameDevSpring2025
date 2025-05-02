extends MultiplayerSynchronizer

@export var jumping := false

# Synchronized property.
@export var dir := Vector2()

func _ready():
	# Only process for the local player.
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	add_props()

func add_props():
	var _config := SceneReplicationConfig.new()
	
	#config.add_property("position", MultiplayerSynchronizer.PROCESS_MODE_ALWAYS)
	#config.add_property("velocity", MultiplayerSynchronizer.PROCESS_MODE_ALWAYS)

@rpc("call_local")
func jump():
	jumping = true


func _process(_delta):
	dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_action_just_pressed("ui_accept"):
		jump.rpc()
