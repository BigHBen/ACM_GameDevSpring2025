extends CanvasLayer

@onready var color_rect2 : ColorRect = $StatsDisplay/ColorRect2
@onready var pause_menu : Control = $PauseMenu

func magic_fade_out(sec:float):
	#color_rect2.modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(color_rect2, "color", Color.BLACK, sec)
	#tween.tween_property(color_rect2, "modulate", Color(1,1,1,1), sec)
	await tween.finished

func ui_fade_reset(sec:float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(color_rect2, "color", Color(1,1,1,0), sec)
	#tween.tween_property(color_rect2, "modulate", Color(1,1,1,1), sec)
	await tween.finished
