extends OptionButton

const RESOLUTION_DICT = {
	"1152 x 648" : Vector2i(1152, 648),
	"1280 x 720" : Vector2i(1280, 720),
	"1920 x 1080" : Vector2i(1920, 1080),
	"3840 x 2160" : Vector2i(3840, 2160),
}

func add_resolution_items() -> void:
	for resolution_size_text in RESOLUTION_DICT:
		add_item(resolution_size_text)

const TOLERANCE = 20
func resolution_to_index(res:Vector2i) -> int:
	for i in RESOLUTION_DICT.size():
		var stored_res = RESOLUTION_DICT.values()[i]
		if abs(stored_res.x - res.x) <= TOLERANCE and abs(stored_res.y - res.y) <= TOLERANCE:
			return i
	return -1  # Not found
