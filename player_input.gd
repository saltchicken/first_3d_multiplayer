extends MultiplayerSynchronizer

@onready var player = $".."

var input_dir 

# Called when the node enters the scene tree for the first time.
func _ready():
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_dir = Input.get_vector("left", "right", "up", "down")

func _physics_process(_delta):
	input_dir = Input.get_vector("left", "right", "up", "down")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("jump"):
		jump.rpc()

@rpc("call_local")
func jump():
	if multiplayer.is_server():
		player.do_jump = true
