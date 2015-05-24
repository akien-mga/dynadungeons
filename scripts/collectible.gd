extends Area2D

# Nodes
var global
var level

# Member variables
var effect = "bomb_increase"

func _on_body_enter(body):
	if (body extends global.player_script):
		# Remove dummy collider
		level.tilemap_dummy.set_cell(level.world_to_map(get_pos()).x, level.world_to_map(get_pos()).y, -1)
		# Apply effect
		if (effect == "bomb_increase" and body.bomb_quota < global.MAX_BOMBS):
			body.bomb_quota += 1
		elif (effect == "flame_increase" and body.bomb_range < global.MAX_FLAMERANGE):
			body.bomb_range += 1
		elif (effect == "speed_increase" and body.speed < global.MAX_SPEED):
			body.speed += 1
		elif (effect == "life_increase"):
			body.lives += 1
		get_node("AnimationPlayer").play("pickup")

func _on_AnimationPlayer_finished():
	self.queue_free()

func _ready():
	global = get_node("/root/global")
	level = get_node("/root").get_node("Level")
	get_node("Sprite").set_texture(load("res://sprites/pickups/" + effect + ".png"))
