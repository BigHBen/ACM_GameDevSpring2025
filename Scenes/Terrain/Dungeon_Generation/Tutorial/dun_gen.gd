@tool
extends Node3D

@onready var grid_map : GridMap = $GridMap
@export var start : bool = false : set = set_start

@export_range(0,1) var survival_chance : float = 0.25
@export var border_size : int = 20 : set = set_border_size

@export var room_number : int = 4
@export var room_margin : int = 1

@export var room_recursion : int = 15
@export var min_room_size : int = 2
@export var max_room_size : int = 4
@export_multiline var custom_seed : String = "" : set = set_seed

func set_seed(val:String)-> void:
		custom_seed = val
		seed(val.hash())

var room_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint():
		generate()

func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		if grid_map: visualize_border()

func visualize_border():
	grid_map.clear()
	for i in range(-1, border_size+1):
		grid_map.set_cell_item(Vector3i(i,0,-1),3)
		grid_map.set_cell_item(Vector3i(i,0,border_size),3)
		grid_map.set_cell_item(Vector3i(border_size,0,i),3)
		grid_map.set_cell_item(Vector3i(-1,0,i),3)

func generate():
	room_tiles.clear()
	room_positions.clear()
	if custom_seed : set_seed(custom_seed)
	visualize_border()
	for i in room_number:
		make_room(room_recursion)
	
	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	
	for p in room_positions:
		rpv2.append(Vector2(p.x,p.z))
		del_graph.add_point(del_graph.get_available_point_id(),Vector2(p.x,p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(),Vector2(p.x,p.z))
	
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	for i in float(delaunay.size())/3.0:
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1,p2)
		del_graph.connect_points(p2,p3)
		del_graph.connect_points(p1,p3)
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi()% room_positions.size())
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections : Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp,c]
					possible_connections.append(con)
		var connection : PackedInt32Array = possible_connections.pick_random()
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
		
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0],connection[1])
		del_graph.disconnect_points(connection[0], connection[1])
	
	var hallway_graph : AStar2D = mst_graph
	
	for p in del_graph.get_point_ids():
		for c in del_graph.get_point_connections(p):
			if c>p:
				var kill : float = randf()
				if survival_chance > kill:
					hallway_graph.connect_points(p,c)
	
	create_hallways(hallway_graph)
	print("generating....")
	print(room_positions)

func create_hallways(hallway_graph:AStar2D):
	var hallways : Array[PackedVector3Array] = []
	for p in hallway_graph.get_point_ids():
		for c in hallway_graph.get_point_connections(p):
			if c>p:
				var room_from : PackedVector3Array= room_tiles[p]
				var room_to : PackedVector3Array= room_tiles[c]
				
				var tile_from : Vector3 = room_from[0]
				var tile_to : Vector3 = room_to[0]
				
				# Test area
				#print("Room from: %s \nRoom to: %s" % [room_from,room_to])
				
				
				for t in room_from:
					# Testing
					if t: grid_map.set_cell_item(Vector3i(t),4)
					
					if t.distance_squared_to(room_positions[c])<tile_from.distance_squared_to(room_positions[c]):
						tile_from = t
				for t in room_to:
					if t.distance_squared_to(room_positions[p])<tile_to.distance_squared_to(room_positions[p]):
						tile_to = t
				
				var hallway : PackedVector3Array = [tile_from,tile_to]
				#print("Tile from: %s \nTile to: %s" % [tile_from,tile_to])
				hallways.append(hallway)
				
				# Set the main hallway tiles
				#create_wide_hallway(tile_from, tile_to)
				
				grid_map.set_cell_item(tile_from,2)
				grid_map.set_cell_item(tile_to,2)
	
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.update()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	for t in grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x,t.z))
	
	for h in hallways:
		print ("h in hallways: ", h)
		var pos_from : Vector2i = Vector2i(int(h[0].x), int(h[0].z))
		var pos_to : Vector2i = Vector2i(int(h[1].x), int(h[1].z))
		var hall : PackedVector2Array = astar.get_point_path(pos_from,pos_to)
		
		for t in hall:
			var pos : Vector3i = Vector3i(int(t.x),0,int(t.y))
			if grid_map.get_cell_item(pos) < 0:
				grid_map.set_cell_item(pos,1)

# Not working
func create_wide_hallway(tile_from: Vector3, tile_to: Vector3):
	# Calculate the direction from tile_from to tile_to
	var direction = tile_to - tile_from
	direction = direction.normalized() # Normalize to get unit vector
	
	var current_tile = tile_from
	while current_tile != tile_to:
		# Place two tiles: the main one and the one beside it
		grid_map.set_cell_item(Vector3i(current_tile), 2)
		grid_map.set_cell_item(Vector3i(current_tile + Vector3(0, 1, 0)), 2) # 2nd tile (offset vertically)
		
		# Move to the next tile
		current_tile += direction
		if direction.x != 0:
			current_tile.x = round(current_tile.x)
		elif direction.y != 0:
			current_tile.y = round(current_tile.y)
		elif direction.z != 0:
			current_tile.z = round(current_tile.z)
	
	# Ensure the final tile
	grid_map.set_cell_item(Vector3i(tile_to), 2)
	grid_map.set_cell_item(Vector3i(tile_to + Vector3(0, 1, 0)), 2) # Place the second tile beside it

func get_mesh_from_index(index: int) -> Mesh:
	var mesh_library = grid_map.mesh_library
	if mesh_library.has_item(index):
		return mesh_library.get_item_mesh(index)
	else:
		print("Index not found in MeshLibrary")
		return null

func make_room(rec : int):
	if rec<0: return
	
	@warning_ignore("integer_division")
	var width : int = ((randi() % (max_room_size - min_room_size) + min_room_size) / 4) * 4
	var height : int = (randi() % (max_room_size - min_room_size) + min_room_size)
	
	var start_pos : Vector3i
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - width + 1)
	
	for r in range(-room_margin,height+room_margin):
		for c in range(-room_margin,width+room_margin):
			var new_pos : Vector3i = start_pos + Vector3i(c,0,r)
			if grid_map.get_cell_item(new_pos) == 0: # 0 if occupied/-1 if empty
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var other_pos : Vector3i = start_pos + Vector3i(c,0,r)
			grid_map.set_cell_item(other_pos,0)
			room.append(other_pos)
	room_tiles.append(room)
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x,0,avg_z)
	room_positions.append(pos)
