extends CanvasLayer

@onready var color_rect : ColorRect = $ColorRect
@onready var pause_menu : Control = $PauseMenu

func magic_fade_out(sec:float):
	color_rect.modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(color_rect, "modulate", Color(1,1,1,1), sec)
	await tween.finished
