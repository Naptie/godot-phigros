extends AudioStreamPlayer2D


func _on_finished():
	queue_free()
