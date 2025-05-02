extends Label

@onready var player: PlayerCharacter = $"../../.."
var camera_viewport : Camera3D
var updating : bool = false

func _ready() -> void:
	if player != null: 
		player.took_damage.connect(show_damage_text)

func update_current_camera():
	camera_viewport = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	var game_active = get_tree().current_scene is GameManager or get_tree().current_scene is GameManagerMultiplayer
	if player and game_active and !updating: update_floating_healthbar()

@rpc("any_peer","call_local")
func update_floating_healthbar():
	var screen_pos = get_viewport().get_camera_3d().unproject_position(player.global_position + Vector3(0, 4, 0))
	self.global_position = screen_pos 
	self.global_position += Vector2(-self.size.x / 2, 0)

func show_damage_text(amount):
	var angle = randf() * TAU  # TAU - circle constant (2pi)
	var x = cos(angle) * 75.0
	var z = sin(angle) * 75.0
	var new_pos = self.global_position + Vector2(x,z)
	self.text = "-" + str(amount)
	self.show()
	updating = true
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", new_pos, 0.25)
	tween.tween_property(self, "modulate:a", 0, 0.5)
	await tween.finished
	updating = false
	self.modulate.a = 1
	self.hide()
