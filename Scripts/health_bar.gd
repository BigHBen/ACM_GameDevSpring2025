extends ProgressBar

@onready var damagebar = $DamageBar
@onready var timer = $Timer

var health = 0 : set = _set_health

func _set_health(new_health):
	var prev_health = health
	health = min(max_value, new_health)
	value = health
	if health <= 0:
		if owner.has_method("_on_defeat"):
			owner._on_defeat()
		elif owner.owner.has_method("_on_defeat"):
			owner.owner._on_defeat()
		return
	
	if health > prev_health:
		damagebar.value = health
	else:
		timer.start()

func init_health(_health):
	health = _health
	max_value = health
	value = health
	damagebar.max_value = health
	damagebar.value = health

func _on_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(damagebar, "value", health, 1).from(damagebar.value)
