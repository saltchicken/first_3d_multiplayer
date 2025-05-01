extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 5.0

# var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _is_on_floor = true
var alive = true

@onready var animated_sprite = $"AnimatedSprite3D"
@onready var player_name_label = %PlayerNameLabel

func _enter_tree():
	%InputSynchronizer.set_multiplayer_authority(name.to_int())

func _ready():
	GameManager.game_state_changed.connect(_on_game_state_changed)
	# if multiplayer.get_unique_id() == player_id:
	# 	$Camera2D.make_current()
	# else:
	# 	$Camera2D.enabled = false
	#
func _on_game_state_changed(key, _value):
	print("Game state changed")
	if key == "players":
		if GameManager.game_state.players.has(name):
			player_name_label.text = GameManager.game_state.players[name].name
		else:
			player_name_label.text = "Player " + name


func _apply_animations(_delta):
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.x > 0:
		animated_sprite.play("walk_right")
	elif direction.x < 0:
		animated_sprite.play("walk_left")
	elif direction.z > 0:
		animated_sprite.play("walk_down")
	elif direction.z < 0:
		animated_sprite.play("walk_up")
	else:
		animated_sprite.play("idle")

	# # Play animations
	# if _is_on_floor:
	# 	if direction == 0:
	# 		animated_sprite.play("idle")
	# 	else:
	# 		animated_sprite.play("run")
	# else:
	# 	animated_sprite.play("jump")

func _apply_movement_from_input(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if %InputSynchronizer.input_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Apply movement
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()



func _physics_process(delta):
	if multiplayer.is_server():
		_is_on_floor = is_on_floor()
		_apply_movement_from_input(delta)

	if not multiplayer.is_server():
		_apply_animations(delta)
	# Add the gravity.
		# Handle jump.
		# if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		# 	velocity.y = JUMP_VELOCITY
		#
		# if Input.is_action_just_pressed("ui_cancel"):
		# 	#$"../".exit_game(name.to_int())
		# 	get_tree().quit()

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		# var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
