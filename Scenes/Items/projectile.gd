class_name Projectile extends RayCast3D

@export var speed : float = 10.0
@onready var hit_box: HitBox = $HitBox

var type : String

func _ready() -> void:
	$Timer.timeout.connect(cleanup)
	$HitBox/CollisionShape3D.disabled = false
	if get_parent() is ProjectileLauncher and get_parent().player:
		var player : PlayerCharacter = get_parent().player
		match player.player_type:
			player.PlayerType.ROGUE: type = "Rogue"
			player.PlayerType.MAGE: 
				type = "Mage"

func _physics_process(delta: float) -> void:
	position += global_basis * Vector3.FORWARD * speed * delta
	target_position = Vector3.FORWARD * speed * delta
	force_raycast_update()
	var collider = get_collider()
	if is_colliding() or hit_box.get_overlapping_areas().size() > 0:
		global_position = get_collision_point()
		$HitBox/CollisionShape3D.disabled = true
		if collider.is_in_group("Enemy") or type == "Mage":
			cleanup()
		set_physics_process(false)

func cleanup():
	if type == "Mage":
		$StaticFlame.emitting = false
		$StaticFlame.hide()
		$Flame.emitting = false
		$GPUParticles3D.emitting = false
		$OmniLight3D.light_energy = 0
		await get_tree().create_timer($GPUParticles3D.lifetime).timeout
	queue_free()
