class_name ProjectileLauncher extends Node3D

@onready var player: PlayerCharacter = $"../.."
var projectile

@onready var timer: Timer = $Timer

func configure_launcher(type):
	if player:
		match type:
			player.PlayerType.ROGUE:
				projectile = preload("res://Scenes/Items/arrow.tscn")
			player.PlayerType.MAGE:
				projectile = preload("res://Scenes/Items/mage_beam.tscn")

func fire():
	if !timer.is_stopped() or !projectile: return
	timer.start(0.1)
	var attack = projectile.instantiate()
	self.add_child(attack)
	attack.global_transform = global_transform
