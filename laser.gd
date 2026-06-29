extends Area2D

@export var speed: float = 1000.0

func _ready() -> void:
	# Connect to screen_exited signal to auto-free when offscreen
	var notifier = $VisibleOnScreenNotifier2D
	notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	# Move straight up (-Y axis)
	position.y -= speed * delta

func _on_screen_exited() -> void:
	queue_free()
