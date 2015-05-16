extends KinematicBody2D

# This is a simple collision demo showing how
# the kinematic cotroller works.
# move() will allow to move the node, and will
# always move it to a non-colliding spot, 
# as long as it starts from a non-colliding spot too.

# Nodes and scenes
var global

# Constants
const MOTION_SPEED = 160

# Member variables
export var id = 1
export var char = "goblin-brown"
var dead = false
var old_motion = Vector2()
var anim = "down_idle"
var new_anim = ""

var max_bombs = 3
var bomb_range = 2
var active_bombs = []
var collision_exceptions = []

func place_bomb():
	var bomb = global.bomb_scene.instance()
	bomb.cell_pos = global.world_to_map(self.get_pos())
	bomb.set_pos(global.map_to_world(bomb.cell_pos))
	bomb.player = self
	bomb.bomb_range = self.bomb_range
	bomb.get_node("StaticBody2D").add_collision_exception_with(self)
	self.collision_exceptions.append(bomb)
	global.bomb_manager.add_child(bomb)
	active_bombs.append(bomb)

func die():
	set_fixed_process(false)
	get_node("CharSprite").hide()
	get_node("AnimationPlayer").play("death")
	dead = true

func process_movement(delta):
	var motion = Vector2(0,0)
	
	if (Input.is_action_pressed(str(id) + "_move_up")):
		motion += Vector2(0,-1)
	if (Input.is_action_pressed(str(id) + "_move_down")):
		motion += Vector2(0,1)
	if (Input.is_action_pressed(str(id) + "_move_left")):
		motion += Vector2(-1,0)
	if (Input.is_action_pressed(str(id) + "_move_right")):
		motion += Vector2(1,0)
	
	motion = motion.normalized() * MOTION_SPEED * delta
	move(motion)
	
	# Too many slide attempts provide "jumping" through tiles
	# TODO: Needs investigating as even with one attempt some unused effects
	# can be seen when going diagonally against walls
	var slide_attempts = 1
	while(is_colliding() and slide_attempts > 0):
		motion = get_collision_normal().slide(motion)
		move(motion)
		slide_attempts -= 1
	
	if (old_motion != motion):
		if (motion == Vector2(0,0)):
			new_anim += "_idle"
		elif abs(motion.x) > 0:
			get_node("CharSprite").set_flip_h(motion.x < 0)
			new_anim = "side"
		elif motion.y > 0:
			new_anim = "down"
		elif motion.y < 0:
			new_anim = "up"
	
	old_motion = motion
	
	if (new_anim != anim):
		anim = new_anim
		get_node("AnimationPlayer").play(anim)

func process_actions():
	# Drop a bomb on the player's tile
	if (Input.is_action_pressed(str(id) + "_drop_bomb") and active_bombs.size() < max_bombs):
		for bomb in collision_exceptions:
			if (bomb.cell_pos == global.world_to_map(self.get_pos())):
				return
		place_bomb()

func process_explosions():
	for trigger_bomb in global.exploding_bombs:
		for bomb in [ trigger_bomb ]  + trigger_bomb.chained_bombs:
			# FIXME: This flame_cells stuff is really getting messy
			for cell_dict in bomb.flame_cells:
				if (global.world_to_map(self.get_pos()) == cell_dict.pos):
					self.die()

func _fixed_process(delta):
	process_movement(delta)
	process_actions()
	process_explosions()
	
	for bomb in collision_exceptions:
		if (self.get_pos().x < (bomb.cell_pos.x - 0.5)*global.TILE_SIZE \
			or self.get_pos().x > (bomb.cell_pos.x + 1.5)*global.TILE_SIZE \
			or self.get_pos().y < (bomb.cell_pos.y - 0.5)*global.TILE_SIZE \
			or self.get_pos().y > (bomb.cell_pos.y + 1.5)*global.TILE_SIZE):
			bomb.get_node("StaticBody2D").remove_collision_exception_with(self)
			collision_exceptions.erase(bomb)

func _on_AnimationPlayer_finished():
	if (dead):
		self.queue_free()

func _ready():
	# Initialisations
	global = get_node("/root/global")
	get_node("CharSprite").set_sprite_frames(load("res://sprites/" + char + ".xml"))
	
	set_fixed_process(true)
