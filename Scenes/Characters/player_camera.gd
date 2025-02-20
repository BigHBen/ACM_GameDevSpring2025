extends Camera3D

@onready var target : CharacterBody3D = $"../.." # The player (CharacterBody3D)
@onready var area : Area3D = $Area3D # The Area3D node for detecting collisions
@onready var raycast : RayCast3D = $RayCast3D
@onready var collision_shape : CollisionShape3D = $Area3D/CollisionShape3D  # The collision shape used in the Area3D
var zoom_distance : float = 5.0  # Default zoom distance (distance from the target)
var min_zoom : float = 2.0  # Minimum zoom (camera close to player)
var max_zoom : float = 8.0  # Maximum zoom (camera farther from player)
var zoom_speed : float = 2.0  # Speed at which to zoom in/out
var offset : Vector3 = Vector3(0, 12.5, 0)

func _ready():
	# Set up the Area3D to monitor the target's position
	area.global_transform.origin = target.global_transform.origin
	area.monitoring = true  # Enable collision monitoring

	update_camera_position()

func _process(delta):
	# Update the camera position
	#update_camera_position()
	var target_position = target.global_transform.origin + offset
	# Zoom based on the collision
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()  # The point where the ray hit
		global_transform.origin = collision_point  # Move the camera to that point (to avoid clipping)
	else:
		# If there's no collision, the camera can follow the target normally
		global_transform.origin = target_position

func update_camera_position():
	# Calculate the new position based on the zoom distance and target's position
	var camera_position = target.global_transform.origin + Vector3(0, 2, -zoom_distance)  # Adjust this to fit your needs
	global_transform.origin = camera_position  # Set the camera position
