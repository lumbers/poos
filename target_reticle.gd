extends Sprite3D

func _process(delta):
	# Spin around the Z axis so it rotates flat against the card!
	rotation.z += 2.0 * delta
