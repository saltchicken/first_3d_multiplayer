extends MultiplayerSynchronizer

@onready var player = $".."
@onready var pause_menu = %PauseMenu
@onready var camera_pivot = $"../CameraPivot"  # Reference to the camera pivot

var input_dir
var input_jump
var input_push = false
var input_run = false

var is_paused = false

func _ready():
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_dir = Input.get_vector("left", "right", "up", "down")

func _physics_process(_delta):
	var raw_input = Input.get_vector("left", "right", "up", "down")
	
	# Transform input based on camera rotation
	if raw_input.length() > 0.1:
		var cam_y_rotation = camera_pivot.global_rotation.y
		var forward = Vector2(0, 1).rotated(-cam_y_rotation)  # Note the negative rotation
		var right = Vector2(1, 0).rotated(-cam_y_rotation)     # Same negative rotation
		
		# Combine them based on input
		input_dir = right * raw_input.x + forward * raw_input.y

		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()
	else:
		input_dir = Vector2.ZERO
	input_run = Input.is_action_pressed("run")
	input_jump = Input.get_action_strength("jump")
	input_push = Input.get_action_strength("push")
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

func leave_game():
	multiplayer.multiplayer_peer.close()
	queue_free()
	GameManager.LeaveGame()

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		# Show pause menu
		pause_menu.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Optional: pause game for this player only
		# get_tree().paused = true
	else:
		pause_menu.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Optional: unpause game for this player only
		# get_tree().paused = false
	
	print("Pause toggled: " + str(is_paused))
