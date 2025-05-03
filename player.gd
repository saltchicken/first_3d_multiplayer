extends CharacterBody3D

const SPEED = 2.5
const RUN_SPEED_MULTIPLIER = 1.8
const JUMP_VELOCITY = 2.5

const PUSH_FORCE = 200.0
const PUSH_RADIUS = 2.0
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
var current_animation = "idle_down"
var animation_speed = 1.0

@onready var animated_sprite = $"AnimatedSprite3D"
@onready var player_name_label = %PlayerNameLabel
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D

func _enter_tree():
	%InputSynchronizer.set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("players")
	GameManager.game_state_changed.connect(_on_game_state_changed)
	PingManager.ping_updated.connect(_on_ping_updated)
	if multiplayer.get_unique_id() == name.to_int():
		print("Set up player for client side")
		camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		print("Player init on instance that is not client")

	if multiplayer.is_server():
		# Find all lava areas in the scene
		var lava_areas = get_tree().get_nodes_in_group("lava")
		for lava in lava_areas:
			lava.body_entered.connect(_on_lava_entered)

func _physics_process(delta):
	if multiplayer.is_server():
		_is_on_floor = is_on_floor()
		if alive:
			_apply_movement_from_input(delta)
	
	# Apply server-determined animations
	animated_sprite.play(current_animation)
	animated_sprite.speed_scale = animation_speed
	
	# Only handle camera-relative sprite rotation on client
	if multiplayer.get_unique_id() == name.to_int():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if %InputSynchronizer.input_dir.length() < 0.1:
				# Make sprite face the camera when not moving
				animated_sprite.rotation.y = -global_rotation.y - last_camera_facing_rotation
			else:
				animated_sprite.rotation.y = 0
				last_camera_facing_rotation = -global_rotation.y

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
	
	# Update cooldown timers
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	if push_cooldown > 0:
		push_cooldown -= delta
	
	# Handle push attack
	if input_push and push_cooldown <= 0:
		perform_push_attack()
		push_cooldown = PUSH_COOLDOWN_DURATION
	
	# Calculate movement direction based on client's camera rotation
	var direction = Vector3.ZERO
	if input_dir.length() > 0.1:
		# Convert 2D input to 3D direction using client's camera rotation
		direction.x = input_dir.x
		direction.z = input_dir.y
		direction = direction.normalized()
	
		if abs(input_dir.x) > abs(input_dir.y):
			last_direction = "right" if input_dir.x > 0 else "left"
		else:
			last_direction = "down" if input_dir.y > 0 else "up"
	
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

	# Set animation state based on server-side logic
	if not alive:
		current_animation = "death"
		animation_speed = 1.0
		return
		
	# Handle push animation
	if input_push and push_cooldown <= 0:
		current_animation = "push_" + last_direction
		animation_speed = 1.0
		return
		
	# Handle jump animation
	if input_jump and is_on_floor() and jump_cooldown_timer <= 0:
		current_animation = "jump_" + last_direction
		animation_speed = 1.0
		return
		
	# Handle movement animations
	if input_dir.length() > 0.1:
		if input_run:
			current_animation = "run_" + last_direction
			animation_speed = 1.0
		else:
			current_animation = "walk_" + last_direction
			animation_speed = 1.0
	else:
		current_animation = "idle_" + last_direction
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
