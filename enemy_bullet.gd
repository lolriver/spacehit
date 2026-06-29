extends Area2D

@export var speed: float = 550.0
var velocity: Vector2 = Vector2.ZERO
var is_homing: bool = false

func _ready() -> void:
	# Clean up bullet when offscreen
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Homing tracking logic
	if is_homing:
		var player_node = get_tree().current_scene.get_node_or_null("Player")
		if player_node:
			var target_x = player_node.global_position.x
			position.x = lerp(position.x, target_x, 1.8 * delta)
			
	# Move using custom velocity if set, otherwise standard straight down
	if velocity != Vector2.ZERO:
		position += velocity * delta
	else:
		position.y += speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage()
		queue_free()
