extends Sprite2D


func _ready():
	var angle = randf_range(0, 2 * PI)
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", Vector2(cos(angle), sin(angle)) * randf_range(100, 400), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "self_modulate:a", 0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 30, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN).set_delay(0.3)

