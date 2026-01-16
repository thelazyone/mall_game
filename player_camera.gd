extends Camera3D

# Reference to the player
var player

# Camera settings
@export var rotation_speed: float = 5.0  # How fast the camera rotates (higher = less inertia)
var target_rotation: float = 0.0  # Target Y rotation for the camera

func _ready() -> void:
	# Ensure camera is at (0, 0, 0)
	position = Vector3.ZERO
	
	# Find the player node
	if get_parent():
		player = get_parent().find_child("Player", true, false)
	
	if player:
		print("Camera found Player node")
	else:
		print("WARNING: Camera could not find Player node")

func _process(delta: float) -> void:
	if not player:
		return
	
	# Calculate the direction from camera to player (only on XZ plane)
	var direction_to_player = player.position - position
	
	# Calculate the target rotation angle (only Y axis)
	# We use atan2(x, z) and negate to fix the direction
	target_rotation = atan2(-direction_to_player.x, -direction_to_player.z)
	
	# Smoothly interpolate the camera's rotation towards the target
	# This creates the spring-like inertia effect
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
