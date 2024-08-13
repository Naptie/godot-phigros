extends AnimatedSprite2D


func _on_animation_finished():
	queue_free()
