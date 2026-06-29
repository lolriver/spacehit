extends Area2D

@export var speed: float = 200.0
@export var explosion_scene: PackedScene = preload("res://explosion.tscn")

func _ready() -> void:
	# Connect collision and screen exit signals
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	# Fall downward along the Y-axis
	position.y += speed * delta

func _on_screen_exited() -> void:
	# Free memory when asteroid falls off the bottom of the screen
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		# Notify main scene to add score
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("add_score"):
			main_scene.add_score(10)
		
		# Instantiate and spawn the explosion particle effect
		if explosion_scene:
			var explosion = explosion_scene.instantiate()
			explosion.global_position = global_position
			get_parent().add_child(explosion)
		
		# Destroy laser projectile and this asteroid using call_deferred to avoid physics warnings
		area.call_deferred("queue_free")
		call_deferred("queue_free")
	elif area.is_in_group("player"):
		# Notify main scene that player is hit to trigger Game Over screen
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("trigger_game_over"):
			main_scene.trigger_game_over()
		call_deferred("queue_free")
