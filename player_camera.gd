extends Camera3D

# Reference to the player
var player
var geometry

# Camera settings
@export var rotation_speed: float = 5.0  # How fast the camera rotates (higher = less inertia)
@export var vertical_speed: float = 3.0  # How fast the camera follows vertical movement (higher = less inertia)
var target_rotation: float = 0.0  # Target Y rotation for the camera
var target_y_position: float = 0.0  # Target Y position for the camera

func _ready() -> void:
	# Start at origin
	position = Vector3.ZERO
	
	# Find the player node
	if get_parent():
		player = get_parent().find_child("Player", true, false)
		geometry = get_parent().find_child("Geometry", true, false)
	
	if player:
		print("Camera found Player node")
	else:
		print("WARNING: Camera could not find Player node")
	
	if geometry:
		print("Camera found Geometry node")
	else:
		print("WARNING: Camera could not find Geometry node")

func _process(delta: float) -> void:
	if not player:
		return
	
	# Keep camera at world origin for XZ (don't follow player horizontally)
	position.x = 0.0
	position.z = 0.0
	
	# Calculate the direction from camera to player (only on XZ plane for rotation)
	var direction_to_player = player.position - position
	
	# Calculate the target rotation angle (only Y axis)
	# We use atan2(x, z) and negate to fix the direction
	target_rotation = atan2(-direction_to_player.x, -direction_to_player.z)
	
	# Smoothly interpolate the camera's rotation towards the target
	# This creates the spring-like inertia effect
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	# Smoothly follow vertical position based on floor height (not jumps)
	if geometry and "path_position" in player and player.path_position:
		# Get the geometry-based position which includes floor height
		var geometry_pos = geometry.get_position(player.path_position)
		target_y_position = geometry_pos.y
		
		# Smoothly interpolate camera's Y position towards target
		position.y = lerp(position.y, target_y_position, vertical_speed * delta)
	else:
		# Fallback: follow player's Y position with smoothing
		position.y = lerp(position.y, player.position.y, vertical_speed * delta)
