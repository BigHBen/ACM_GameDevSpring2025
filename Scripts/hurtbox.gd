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
		for child in hitbox.get_parent().get_children(): # Prevent player from hitting itself
			if child == self: 
				#print("Found ",self, " in ",hitbox.owner," while attempting to hit ", self.owner)
				return
		call_damage_function(hitbox.damage)

func call_damage_function(damage):
	if get_tree().current_scene is GameManagerMultiplayer: # Check if pvp is enabled
		var game = get_tree().current_scene
		if owner.is_in_group("Player") and !game.multiplayer_pvp: return
			#print(game.multiplayer_pvp)
	
	#print(hitbox.owner, ": HIT - MULTIPLAYER AUTHORITY: ",hitbox.owner.is_multiplayer_authority())
	if owner.has_method("take_damage"):
		owner.take_damage.rpc_id(owner.name.to_int(),damage)
		if owner.is_in_group("Enemy"):
			visible = false
			timer.start()

func _on_timer_timeout() -> void:
	visible = true
