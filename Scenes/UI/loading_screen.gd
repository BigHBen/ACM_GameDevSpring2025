extends CanvasLayer

var scene_path : String
var progress = []
var args = []

signal scene_loading_finished
func _initialize(scene,extra:=[]):
	scene_path = scene
	args.append(extra)

func _ready():
	if ResourceLoader.exists(scene_path, "PackedScene"):
		ResourceLoader.load_threaded_request(scene_path, "PackedScene")
		load_async()
	else:
		print("Requested resource does not exist at path!")

func load_async():
	get_tree().change_scene_to_file(scene_path)
	scene_loading_finished.emit()
	#var result = ResourceLoader.load_threaded_get_status(scene_path, progress)
	#if result == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		#print("Loading in progress: " + str(progress[0]))
	#
	#elif result == ResourceLoader.THREAD_LOAD_LOADED:
		#var scene_to_load = ResourceLoader.load_threaded_get(scene_path)
		#var scene_instance = scene_to_load.instantiate()
		#get_tree().root.add_child(scene_instance)
		#scene_loading_finished.emit()
