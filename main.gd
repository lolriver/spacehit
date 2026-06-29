extends Node2D

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var final_score_label: Label = $UI/GameOverScreen/FinalScoreLabel
@onready var player: Area2D = $Player

var score: int = 0
var viewport_width: float = 720.0
var is_game_over: bool = false

func _ready() -> void:
	viewport_width = get_viewport_rect().size.x
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Start with standard spawn rate
	spawn_timer.wait_time = 1.2
	spawn_timer.start()
	
	update_score_label()

func _on_spawn_timer_timeout() -> void:
	spawn_enemy()

func spawn_enemy() -> void:
	if is_game_over:
		return
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		var spawn_x = randf_range(40.0, viewport_width - 40.0)
		enemy.position = Vector2(spawn_x, -50.0)
		
		# Slowly increase asteroid speed ranges based on current score
		var base_speed_min = 200.0 + (score / 10.0) * 10.0
		var base_speed_max = 350.0 + (score / 10.0) * 15.0
		# Clamp min/max speeds so the game remains fair yet challenging
		enemy.speed = randf_range(clamp(base_speed_min, 200.0, 500.0), clamp(base_speed_max, 350.0, 750.0))
		add_child(enemy)

func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	update_score_label()
	
	# Gradually decrease spawn interval down to a fast-paced 0.35s
	var new_wait_time = 1.2 - (score / 10.0) * 0.04
	spawn_timer.wait_time = max(0.35, new_wait_time)

func update_score_label() -> void:
	if score_label:
		score_label.text = "SCORE: " + str(score)

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	# Stop spawns
	spawn_timer.stop()
	
	# Disable the player ship
	if player:
		player.hide()
		player.set_process(false)
		player.set_deferred("monitoring", false)
		player.set_deferred("monitorable", false)
		
	# Display final score
	if final_score_label:
		final_score_label.text = "FINAL SCORE: " + str(score)
		
	# Display Game Over screen UI overlay
	if game_over_screen:
		game_over_screen.show()

func _input(event: InputEvent) -> void:
	if is_game_over:
		# Check for touch drag or mouse tap
		var is_tap = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
		if is_tap:
			restart_game()

func restart_game() -> void:
	get_tree().call_deferred("reload_current_scene")
