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
	var player_parent_children
	if hitbox.owner.is_in_group("Enemy") or hitbox.owner.is_in_group("EnemyProjectile"):
		if owner.has_method("take_damage"):
			owner.take_damage(hitbox.damage)
			if owner.is_in_group("Player"):
				visible = false
				timer.start()
	if hitbox.owner.is_in_group("Player") or hitbox.owner.is_in_group("PlayerProjectile"):
		if hitbox.owner.is_in_group("PlayerProjectile"):
			if hitbox.owner.get_parent() is ProjectileLauncher and hitbox.owner.get_parent().player: 
				player_parent_children = hitbox.owner.get_parent().player.get_children()
				for child in player_parent_children: # Prevent player from hitting itself w projectile
					if child == self.get_parent(): return
		player_parent_children = hitbox.get_parent().get_children()
		for child in player_parent_children: # Prevent player from hitting itself
			if child == self: 
				#print("Found ",self, " in ",hitbox.owner," while attempting to hit ", self.owner)
				return
		if hitbox.owner.is_in_group("PlayerProjectile"):
			call_damage_function(hitbox.damage,hitbox.owner.get_parent().player.position)
		else: call_damage_function(hitbox.damage)

func call_damage_function(damage,pos = Vector3.ZERO):
	if get_tree().current_scene is GameManagerMultiplayer: # Check if pvp is enabled
		var game = get_tree().current_scene
		if owner.is_in_group("Player") and !game.multiplayer_pvp: return
			#print(game.multiplayer_pvp)
	
	#print(hitbox.owner, ": HIT - MULTIPLAYER AUTHORITY: ",hitbox.owner.is_multiplayer_authority())
	if owner.has_method("take_damage"):
		if owner.is_in_group("Player"): owner.take_damage.rpc_id(owner.name.to_int(),damage)
		if owner.is_in_group("Enemy"):
			if owner.is_multiplayer_authority(): owner.take_damage.rpc(damage)
			if owner.has_method("set_hit_from"): owner.set_hit_from(pos)
			visible = false
			timer.start()

func _on_timer_timeout() -> void:
	visible = true
