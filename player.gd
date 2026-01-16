extends Node3D

# Reference to the geometry node
# Option 1: Use unique name (requires Geometry node to be marked with % in scene tree)
# @onready var geometry = %Geometry
# Option 2: Use get_node with path from root
# @onready var geometry = get_node("/root/Geometry")
# Option 3: Find it at runtime (most flexible)
var geometry

# Player's position along the path
var path_position

# Movement speed (units per second along the path)
@export var movement_speed: float = 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Player ready!")
	
	# Try to find the Geometry node in different ways
	if not geometry:
		# Try searching in parent's children first
		if get_parent():
			geometry = get_parent().find_child("Geometry", true, false)
		
		# Try unique name if that didn't work
		if not geometry and has_node("%Geometry"):
			geometry = get_node("%Geometry")
		
		if geometry:
			print("Found Geometry node")
		else:
			print("WARNING: Could not find Geometry node in _ready()")

# Initialize the player's position - called by mall.gd after geometry is ready
func initialize_position() -> void:
	if not geometry:
		push_error("Cannot initialize position: geometry not found")
		return
	
	if not geometry.is_path_defined:
		push_error("Cannot initialize position: path not defined")
		return
	
	path_position = geometry.create_position(0.0)
	update_player_transform()
	print("Player position initialized at distance: ", path_position.distance)
	print("Player world position: ", position)


func _process(delta: float) -> void:

	var movement_input = 0.0	
	
	# Checking if the move_left and move_right buttons are pressed right now.
	if Input.is_action_pressed("move_left"):
		movement_input += 1.0
	if Input.is_action_pressed("move_right"):
		movement_input -= 1.0



	if movement_input != 0.0:
		var distance_delta = movement_input * movement_speed * delta
		geometry.translate(path_position, distance_delta)
		update_player_transform()
		print("New position: ", position)


# Update the player's 3D position and rotation based on path position
func update_player_transform() -> void:
	# Get 2D position from geometry
	var pos_2d = geometry.get_position(path_position)
	var facing_2d = geometry.get_facing(path_position)
	
	# Update 3D position (keeping y coordinate)
	position.x = pos_2d.x
	position.z = pos_2d.y  # Map 2D y to 3D z
	
	# Update rotation to face movement direction
	if facing_2d.length() > 0:
		var angle = atan2(facing_2d.x, facing_2d.y)
		rotation.y = angle
