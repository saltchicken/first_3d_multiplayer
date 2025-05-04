extends Node3D

@export var spacing: float = 0.25
@export var vertical: bool = true

func _ready():
	reposition_children()

func reposition_children():
	for i in range(get_child_count()):
		var child := get_child(i)
		var pos := Vector3.ZERO
		if vertical:
			pos.y = -i * spacing  # Negative to stack downward
		else:
			pos.x = i * spacing
		child.position = pos

