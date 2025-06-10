class_name ProjectileLauncher extends Node3D

@onready var player: PlayerCharacter = $"../.."
var projectile

@onready var timer: Timer = $Timer

var regular_arrow = preload("res://Scenes/Items/arrow.tscn")
var special_arrow = preload("res://Scenes/Items/special_arrow.tscn")

func configure_launcher(type):
	if player:
		match type:
			player.PlayerType.ROGUE:
				projectile = preload("res://Scenes/Items/arrow.tscn")
			player.PlayerType.MAGE:
				projectile = preload("res://Scenes/Items/mage_beam.tscn")

func fire(special=false):
	if special: 
		if player.player_type == player.PlayerType.ROGUE: projectile = special_arrow
	else: 
		if player.player_type == player.PlayerType.ROGUE: projectile = regular_arrow
	
	if !timer.is_stopped() or !projectile: return
	timer.start(0.1)
	var attack = projectile.instantiate()
	self.add_child(attack)
	attack.global_transform = global_transform
