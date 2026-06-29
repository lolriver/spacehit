extends CPUParticles2D

func _ready() -> void:
	# Automatically emit the explosion particles
	emitting = true
	# Wait for lifetime plus a buffer, then clean up
	get_tree().create_timer(lifetime + 0.1).timeout.connect(queue_free)
