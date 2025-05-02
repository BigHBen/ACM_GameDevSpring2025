class_name EnemyProjectileLauncher extends Node3D

@onready var enemy : Enemy_Turret = $".."
var projectile

@onready var timer: Timer = $Timer

func configure_launcher(type):
	if enemy:
		match type:
			enemy.EnemyType.ROGUE:
				projectile = preload("res://Scenes/Items/cannon_ball.tscn")

func fire():
	projectile = preload("res://Scenes/Items/cannon_ball.tscn")
	if !timer.is_stopped() or !projectile: return
	timer.start(0.1)
	var attack = projectile.instantiate()
	self.add_child(attack)
	attack.global_transform = global_transform
