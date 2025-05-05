extends Node3D

@export var spacing: float = 0.25
@export var vertical: bool = true
@export var excluded_names: Array[String] = []

func _ready():
	reposition_children()

func is_authority_client():
	var parent = get_parent()
	return parent.role == parent.Role.AUTHORITY_CLIENT

func remove_excluded_children():
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		print(child.name)
		if excluded_names.has(child.name):
			child.queue_free()
	reposition_children()

func reposition_children():
	for i in range(get_child_count()):
		var child := get_child(i)
		var pos := Vector3.ZERO
		if vertical:
			pos.y = i * spacing  # Negative to stack downward
		else:
			pos.x = i * spacing
		child.position = pos
		child.billboard = BaseMaterial3D.BILLBOARD_ENABLED

