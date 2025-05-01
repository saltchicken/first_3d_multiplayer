extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Join.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	var player_name = %Name.text
	if player_name.strip_edges().is_empty():
		player_name = "Player" + str(randi() % 1000)
	self.hide()
	GameManager.StartGame()
	GameManager.player_join()
