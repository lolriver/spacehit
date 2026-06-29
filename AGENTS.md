Project: Neon Starfighter (Simple Space Arcade)

Engine: Godot 4.x
Target: Mobile Portrait Mode

Agent Constraints & Rules of Engagement:

Camera: Fixed top-down 2D, portrait orientation (e.g., 720x1280).

Player: A ship fixed near the bottom Y-axis. It only moves left and right along the X-axis by following the player's mouse/touch drag.

Shooting: The player ship uses a Timer to automatically instance and shoot laser projectiles straight up (-Y axis).

Enemies: Spawn simple falling hazards (like asteroids) at random X coordinates at the top of the screen.

Collisions: If a laser hits an asteroid, both are destroyed (queue_free()) and a Score variable goes up. If an asteroid hits the player, the game resets.
