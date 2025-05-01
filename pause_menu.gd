extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Join.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	self.hide()
	GameManager.player_join()

