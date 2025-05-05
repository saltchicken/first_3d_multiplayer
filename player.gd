extends CharacterBody3D

enum Role {SERVER, AUTHORITY_CLIENT, PEER_CLIENT}
var role = Role.PEER_CLIENT

const SPEED = 2.5
const RUN_SPEED_MULTIPLIER = 1.8
const JUMP_VELOCITY = 2.5

const PUSH_FORCE = 200.0
const PUSH_RADIUS = 1.2
var push_cooldown = 0.0
var push_animation_timer = 0.0
const PUSH_COOLDOWN_DURATION = 0.1

const JUMP_ANIMATION_DURATION = 0.5
var jump_animation_timer = 0.0
const JUMP_COOLDOWN = 0.7
var jump_cooldown_timer = 0.0

const FRICTION = 0.2

var last_direction = "down"
var _is_on_floor = true
var alive = true

var last_camera_facing_rotation = 0.0
var current_animation_base = "idle" # Base animation without direction
var animation_speed = 1.0

var synced_last_direction = "down"
var direction
var cam_basis

var camera_angle_rad

@onready var animated_sprite = $"AnimatedSprite3D"
@onready var player_name_label = %PlayerNameLabel
@onready var input_rotation_label = %InputRot
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D

@onready var debug_stats = %DebugStats

func debug(message):
	print("%s: %s" % [name, message])

func _enter_tree():
	%InputSynchronizer.set_multiplayer_authority(name.to_int())

func _ready_server():
	add_to_group("players")
	var lava_areas = get_tree().get_nodes_in_group("lava")
	for lava in lava_areas:
		lava.body_entered.connect(_on_lava_entered)

func _ready_authority_client():
	add_to_group("players")
	GameManager.game_state_changed.connect(_on_game_state_changed)
	PingManager.ping_updated.connect(_on_ping_updated)
	camera.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# TODO: Remove this when debug_stats is removed
	if debug_stats:
		debug_stats.remove_excluded_children()

func _ready_peer_clients():
	add_to_group("players")
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _physics_process_server(delta):
	_is_on_floor = is_on_floor()
	if alive:
		_apply_movement_from_input(delta)
	
	last_direction = synced_last_direction

func _physics_process_authority_client(_delta):
	var input_dir = %InputSynchronizer.input_dir
	var input_rot = %InputSynchronizer.input_rot
	input_rotation_label.text = "Input Rotation: %.2f" % %InputSynchronizer.input_rot
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cam_basis = camera.global_transform.basis
		if input_dir.length() < 0.1:
			animated_sprite.rotation.y = -global_rotation.y - last_camera_facing_rotation
		else:
			# var rotation_matrix = Basis(Vector3.UP, input_rot)
			# var forward = -rotation_matrix.z
			# var right = rotation_matrix.x
			var forward = -cam_basis.z
			var right = cam_basis.x
			
			forward.y = 0
			right.y = 0
			forward = forward.normalized()
			right = right.normalized()
			
			direction = (right * input_dir.x + forward * input_dir.y).normalized()
			direction = Vector2(direction.x, direction.z)
			%POVDir.text = "POV Dir: " + str(direction)
			%InputDir.text = "World Dir: " + str(input_dir)
			
			if abs(direction.x) > abs(direction.y):
				last_direction = "right" if direction.x > 0 else "left"
			else:
				last_direction = "up" if direction.y > 0 else "down"
			animated_sprite.rotation.y = 0
			last_camera_facing_rotation = -global_rotation.y

	# debug(cam_basis)
	# debug(world_dir)
	# debug(input_dir)
	# debug(last_direction)

	%LastDirection.text = "Last Direction: " + last_direction
	_apply_animation()

func _physics_process_peer_client(_delta):
	input_rotation_label.text = "Input Rotation: %.2f" % %InputSynchronizer.input_rot
	last_direction = synced_last_direction

	var authority_player = _find_authority_player()
	if authority_player:
		var to_authority = authority_player.global_position - global_position
		to_authority.y = 0	# Project onto horizontal plane
		to_authority = to_authority.normalized()
		%POVDir.text = "POV Dir: " + str(to_authority)

		var auth_camera = authority_player.get_node_or_null("CameraPivot/Camera3D")
		if auth_camera:
			# Get vector from peer to camera (not to authority player)
			var to_camera = auth_camera.global_position - global_position
			to_camera.y = 0  # Project onto horizontal plane
			to_camera = to_camera.normalized()
			
			# Calculate angle between camera forward and direction to peer
			camera_angle_rad = atan2(to_camera.x, to_camera.z)
			var camera_angle_deg = rad_to_deg(camera_angle_rad)
			
			# Display camera angle for debugging
			%DirToCamera.text = "Angle to camera: %.2f°" % camera_angle_deg
			
			# TODO: Why do these magic numbers work?
			if camera_angle_deg > 90 or camera_angle_deg < -90:
				if last_direction == "up":
					last_direction = "down"
				elif last_direction == "down":
					last_direction = "up"
		
		# Calculate angle in radians
		var forward = -global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var angle_rad = forward.signed_angle_to(to_authority.normalized(), Vector3.UP)
		var angle_deg = rad_to_deg(angle_rad)


		
		# Display angle for debugging
		%RotToPlayer.text = "Angle to auth: %.2f°" % angle_deg
		%LastDirection.text = "Last Direction: " + last_direction

	_apply_animation()

func _apply_animation():
	var full_animation = current_animation_base
	if current_animation_base != "death":
		full_animation += "_" + last_direction
	
	animated_sprite.play(full_animation)
	animated_sprite.speed_scale = animation_speed

func _find_authority_player():
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.name.to_int() == name.to_int():
			continue  # Skip self
		if player.role == Role.AUTHORITY_CLIENT:
			return player
	return null


func _apply_movement_from_input(delta):
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Get synchronized input from client
	var input_dir = %InputSynchronizer.input_dir
	var input_jump = %InputSynchronizer.input_jump
	var input_push = %InputSynchronizer.input_push
	var input_run = %InputSynchronizer.input_run
	
	# Handle jump
	if input_jump and is_on_floor() and jump_cooldown_timer <= 0:
		velocity.y = JUMP_VELOCITY
		jump_cooldown_timer = JUMP_COOLDOWN
		jump_animation_timer = JUMP_ANIMATION_DURATION
	
	# Update cooldown timers
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	if push_cooldown > 0:
		push_cooldown -= delta
	if jump_animation_timer > 0:
		jump_animation_timer -= delta
	if push_animation_timer > 0:
		push_animation_timer -= delta
	
	# Handle push attack
	if input_push and push_cooldown <= 0:
		perform_push_attack()
		push_cooldown = PUSH_COOLDOWN_DURATION
		push_animation_timer = PUSH_COOLDOWN_DURATION
	
	# Calculate movement direction based on client's camera rotation
	var direction = Vector3.ZERO
	if input_dir.length() > 0.1:
		# Convert 2D input to 3D direction using client's camera rotation
		direction.x = input_dir.x
		direction.z = input_dir.y
		direction = direction.normalized()
	
		# Server still tracks direction for other calculations
		if abs(input_dir.x) > abs(input_dir.y):
			last_direction = "right" if input_dir.x > 0 else "left"
		else:
			last_direction = "down" if input_dir.y > 0 else "up"
		synced_last_direction = last_direction
	
	# Apply friction
	velocity.x *= (1.0 - FRICTION)
	velocity.z *= (1.0 - FRICTION)
	
	# Apply movement force
	var current_speed = SPEED
	if input_run:
		current_speed *= RUN_SPEED_MULTIPLIER
	
	if direction:
		velocity.x += direction.x * current_speed * delta * 10.0
		velocity.z += direction.z * current_speed * delta * 10.0
	
	# Cap horizontal speed
	var max_speed = current_speed * 1.2
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.y
	
	# Apply movement
	move_and_slide()

	# Set animation state based on server-side logic (without direction)
	if not alive:
		current_animation_base = "death"
		animation_speed = 1.0
		return
		
	# Handle push animation
	if push_animation_timer > 0:
		current_animation_base = "push"
		animation_speed = 1.0
		return
		
	# Handle jump animation
	if jump_animation_timer > 0:
		current_animation_base = "jump"
		animation_speed = 1.0
		return
		
	# Handle movement animations
	if input_dir.length() > 0.1:
		if input_run:
			current_animation_base = "run"
			animation_speed = 1.0
		else:
			current_animation_base = "walk"
			animation_speed = 1.0
	else:
		current_animation_base = "idle"
		animation_speed = 1.0

func perform_push_attack():
	if not multiplayer.is_server():
		return
	
	# Get synchronized input from client
	var input_dir = %InputSynchronizer.input_dir
	var forward_direction = Vector3.ZERO
	
	if input_dir.length() > 0.1:
		# Use the input direction directly to determine push direction
		# Convert 2D input to 3D direction
		forward_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		# If no input direction, use the character's last known direction
		var direction_map = {
			"up": Vector3(0, 0, -1),
			"down": Vector3(0, 0, 1),
			"left": Vector3(-1, 0, 0),
			"right": Vector3(1, 0, 0)
		}
		forward_direction = direction_map[last_direction]
	
	# Find players in radius
	print(forward_direction)
	print(last_direction)
	var players = get_tree().get_nodes_in_group("players")
	
	for other_player in players:
		if other_player == self:
			continue
		
		# Calculate vector to other player (ignoring Y)
		var to_other = other_player.global_position - global_position
		var to_other_flat = Vector3(to_other.x, 0, to_other.z)
		var distance = to_other_flat.length()
		
		# Check if player is within push radius
		if distance < PUSH_RADIUS:
			# Calculate push direction (away from pusher)
			var push_dir = to_other.normalized()
			var final_push_dir = push_dir * PUSH_FORCE
			final_push_dir.y = 0
			
			# Apply push on server
			other_player.velocity += final_push_dir
			# Send RPC to client
			apply_push.rpc_id(int(other_player.name), final_push_dir)

@rpc("authority")
func apply_push(push_vector):
	velocity += push_vector
	print("Push received: " + str(push_vector))

func _on_lava_entered(body):
	if not multiplayer.is_server():
		return
	if body == self:
		alive = false
		player_died.rpc()
		await get_tree().create_timer(3.0).timeout
		global_position = Vector3(0, 3, 0)	# Respawn position
		alive = true
		player_respawned.rpc()

@rpc("authority")
func player_died():
	alive = false
	animated_sprite.play("death")

	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(0, 0, 0, 1), 2.0)

	if multiplayer.get_unique_id() == name.to_int():
		%InputSynchronizer.set_process(false)
		%InputSynchronizer.set_physics_process(false)

@rpc("authority")
func player_respawned():
	alive = true
	animated_sprite.modulate = Color(1, 1, 1, 1)
	animated_sprite.play("idle_down")
	if multiplayer.get_unique_id() == name.to_int():
		%InputSynchronizer.set_process(true)
		%InputSynchronizer.set_physics_process(true)

func _on_ping_updated(ping_value):
	if multiplayer.get_unique_id() == name.to_int():
		%PingLabel.text = "Ping: " + str(ping_value) + "ms"

func _on_game_state_changed(key, _value):
	if key == "players":
		if GameManager.game_state.players.has(name):
			player_name_label.text = GameManager.game_state.players[name].name
		else:
			player_name_label.text = "Player " + name

func _ready():
	if multiplayer.is_server():
		role = Role.SERVER
	elif multiplayer.get_unique_id() == name.to_int():
		role = Role.AUTHORITY_CLIENT
	
	match role:
		Role.SERVER:
			_ready_server()
		Role.AUTHORITY_CLIENT:
			_ready_authority_client()
		Role.PEER_CLIENT:
			_ready_peer_clients()

func _physics_process(delta):
	match role:
		Role.SERVER:
			_physics_process_server(delta)
		Role.AUTHORITY_CLIENT:
			_physics_process_authority_client(delta)
		Role.PEER_CLIENT:
			_physics_process_peer_client(delta)
