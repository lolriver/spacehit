extends CPUParticles2D

func _ready() -> void:
	emitting = true
	_spawn_flash()
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)


func _spawn_flash() -> void:
	var flash := Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var sides := 8
	for i in sides:
		var angle := TAU * i / sides
		points.append(Vector2(cos(angle), sin(angle)) * 12.0)
	flash.polygon = points
	flash.color = Color(1, 1, 1, 0.9)
	flash.scale = Vector2(0.5, 0.5)
	add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(flash, "color:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(flash.queue_free)
