extends Node3D

#@export var start : bool = false : set = set_start
#@export var clear_fill : bool = false : set = set_clear
@export var torch_grid_map: GridMap
@export var flame_vfx_scene: PackedScene  # Drag in your GPUParticles scene
@export var mesh_lib : MeshLibrary

var z_adjustment : float = 0.5
var y_adjustment : float = 1

const orthogonal_angles = [
	Vector3(0, 0, 0),
	Vector3(0, 0, PI/2),
	Vector3(0, 0, PI),
	Vector3(0, 0, -PI/2),
	Vector3(PI/2, 0, 0),
	Vector3(PI, -PI/2, -PI/2),
	Vector3(-PI/2, PI, 0),
	Vector3(0, -PI/2, -PI/2),
	Vector3(-PI, 0, 0),
	Vector3(PI, 0, -PI/2),
	Vector3(0, PI, 0),
	Vector3(0, PI, -PI/2),
	Vector3(-PI/2, 0, 0),
	Vector3(0, -PI/2, PI/2),
	Vector3(PI/2, 0, PI),
	Vector3(0, PI/2, -PI/2),
	Vector3(0, PI/2, 0),
	Vector3(-PI/2, PI/2, 0),
	Vector3(PI, PI/2, 0),
	Vector3(PI/2, PI/2, 0),
	Vector3(PI, -PI/2, 0),
	Vector3(-PI/2, -PI/2, 0),
	Vector3(0, -PI/2, 0),
	Vector3(PI/2, -PI/2, 0)
]

#func set_start(val:bool)->void:
	#start = val
	#if Engine.is_editor_hint() and start and torch_grid_map:
		#add_flame_vfx(torch_grid_map,flame_vfx_scene)
		#print("Torch flames Generated")
		#start = false
#
## Clear wall tiles
#func set_clear(val:bool)->void:
	#clear_fill = val
	#if Engine.is_editor_hint() and clear_fill:
		#for child in self.get_children():
			#if child is GPUParticles3D: 
				#child.queue_free()
		#clear_fill = false

func _ready() -> void:
	if torch_grid_map and flame_vfx_scene: 
		add_flame_vfx(torch_grid_map, flame_vfx_scene)

# Scan cells in torch gridmap
# Spawn VFX_Fire particle nodes
# Room lit
func add_flame_vfx(map : GridMap,flame_scene : PackedScene):
	var t_map = map.get_used_cells()
	for tile in t_map:
		var mesh_name = mesh_lib.get_item_mesh(map.get_cell_item(tile)).resource_name
		if mesh_name.find("torch") == -1: return
		#print(mesh_lib.get_item_mesh(map.get_cell_item(tile)).resource_name)
		var t_position = map.map_to_local(tile)
		var t_rotation = orthogonal_angles[map.get_cell_item_orientation(tile)]
		var gpu_particles : Node3D = flame_scene.instantiate()
		gpu_particles.rotation = t_rotation
		gpu_particles.transform.origin = t_position
		
		var forward_vector = gpu_particles.transform.basis.z.normalized()
		var up_vector = gpu_particles.transform.basis.y.normalized()
		if mesh_name.find("mounted") != -1:
			gpu_particles.transform.origin += forward_vector * z_adjustment
			gpu_particles.transform.origin += up_vector * y_adjustment
		add_child(gpu_particles)
