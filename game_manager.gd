extends Node

func _ready():
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server...")
		MultiplayerManager.become_host()

func player_join():
	print("player_join called")
	%PauseMenu.hide()
	MultiplayerManager.player_join()


func _on_join_pressed() -> void:
	pass # Replace with function body.
