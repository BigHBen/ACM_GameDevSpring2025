extends Camera3D

@onready var target : CharacterBody3D = $"../../.."

# Camera Effects
@export var rstrength : float = 0.0
@export var shake_fade : float = 10.0
var shake_strength : float = 0.0
var target_max_health : float = 75

func _ready() -> void:
	if target is PlayerCharacter:
		if target.player_data: target_max_health = target.player_data.hp
		target.took_damage.connect(camera_shake)

func camera_shake(amount:float):
	shake_strength = rstrength + amount/(target_max_health) * 5 if amount >= 10 else amount/5

func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_strength = lerp(shake_strength,0.0,shake_fade * delta)
		var new_offset = Vector2(randf_range(-shake_strength,shake_strength),randf_range(-shake_strength,shake_strength))
		h_offset = new_offset.x
		v_offset = new_offset.y
