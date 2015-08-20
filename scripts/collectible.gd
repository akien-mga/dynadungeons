extends Area2D

# Nodes
var global
var level

# Member variables
var effect = "bomb_increase"
var pickable = true

func destroy():
	pickable = false
	get_node("AnimationPlayer").play("destroy")

func _on_body_enter(body):
	if (pickable and body extends global.player_script):
		# Remove dummy collider
		level.tilemap_dummy.set_cell(level.world_to_map(get_pos()).x, level.world_to_map(get_pos()).y, -1)
		# Apply effect
		if (effect == "bomb_increase" and body.bomb_quota < global.MAX_BOMBS):
			body.bomb_quota += 1
		elif (effect == "flame_increase" and body.bomb_range < global.MAX_FLAMERANGE):
			body.bomb_range += 1
		elif (effect == "speed_increase" and body.speed < global.MAX_SPEED):
			body.speed += 1
		elif (effect == "speed_decrease" and body.speed > 0):
			body.speed -= 1
		elif (effect == "confusion"):
			body.set_tmp_powerup("confusion")
		elif (effect == "life_increase"):
			body.lives += 1
		elif (effect == "kick_skill"):
			body.kick = true
		get_node("AnimationPlayer").play("pickup")

func _on_AnimationPlayer_finished():
	self.queue_free()

func _ready():
	global = get_node("/root/global")
	level = get_tree().get_root().get_node("World/Level")
	get_node("Sprite").set_texture(load("res://sprites/pickups/" + effect + ".png"))
