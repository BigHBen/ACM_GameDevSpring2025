class_name HurtBox extends Area3D

@onready var timer = $Timer

func _init() -> void: pass
	#collision_layer = 0
	#collision_mask = 2

func _ready() -> void:
	connect("area_entered", self._on_area_entered)

func _on_area_entered(hitbox: HitBox) -> void:
	if hitbox == null:
		return
	
	if hitbox.owner.is_in_group("Enemy"):
		if owner.has_method("take_damage"):
			owner.take_damage(hitbox.damage)
			if owner.is_in_group("Player"):
				visible = false
				timer.start()
	if hitbox.owner.is_in_group("Player"):
		if owner.has_method("take_damage"):
			owner.take_damage(hitbox.damage)
			if owner.is_in_group("Enemy"):
				visible = false
				timer.start()

func _on_timer_timeout() -> void:
	visible = true
