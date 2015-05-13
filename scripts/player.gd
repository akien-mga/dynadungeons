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
var old_motion = Vector2()
var anim = "down_idle"
var new_anim = ""

var max_bombs = 3
var bomb_range = 2
var active_bombs = 0
var bomb_collision_exceptions = []

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
			get_node("AnimatedSprite").set_flip_h(motion.x < 0)
			new_anim = "side"
		elif motion.y > 0:
			new_anim = "down"
		elif motion.y < 0:
			new_anim = "up"
	
	old_motion = motion
	
	if (new_anim != anim):
		anim = new_anim
		get_node("AnimatedSprite/AnimationPlayer").play(anim)

func process_actions():
	if (Input.is_action_pressed(str(id) + "_drop_bomb") and active_bombs < max_bombs):
		if (!global.bomb_manager.bomb_on_tile(global.world_to_map(self.get_pos()))):
			global.bomb_manager.place_bomb(self, global.world_to_map(self.get_pos()))
			active_bombs += 1

func _fixed_process(delta):
	process_movement(delta)
	process_actions()
	
	for bomb in bomb_collision_exceptions:
		if (self.get_pos().x < (bomb.cell_pos.x - 0.5)*global.TILE_SIZE \
			or self.get_pos().x > (bomb.cell_pos.x + 1.5)*global.TILE_SIZE \
			or self.get_pos().y < (bomb.cell_pos.y - 0.5)*global.TILE_SIZE \
			or self.get_pos().y > (bomb.cell_pos.y + 1.5)*global.TILE_SIZE):
			bomb.get_node("StaticBody2D").remove_collision_exception_with(self)
			bomb_collision_exceptions.erase(bomb)
	
func _ready():
	# Initialisations
	global = get_node("/root/global")
	get_node("AnimatedSprite").set_sprite_frames(load("res://sprites/" + char + ".xml"))
	
	set_fixed_process(true)
