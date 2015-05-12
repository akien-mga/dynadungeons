extends Node

# Nodes and scenes
var global
var bomb_scene = preload("res://scenes/bomb.xscn")

# Constants
var TILE_SIZE
const dir = { "up": Vector2(0,-1),
              "down": Vector2(0,1),
              "left": Vector2(-1,0),
              "right": Vector2(1,0) }
const FLAME_SOURCE = 8
const FLAME_SMALL = 9
const FLAME_LONG_MIDDLE = 10
const FLAME_LONG_END = 11

func place_bomb(var player, cell_pos):
	var bomb = bomb_scene.instance()
	bomb.cell_pos = cell_pos
	bomb.player = player
	bomb.bomb_range = player.bomb_range
	bomb.get_node("StaticBody2D").add_collision_exception_with(player)
	player.bomb_collision_exceptions.append(bomb)
	bomb.set_pos(global.tilemap_destr.map_to_world(cell_pos) + global.TILE_OFFSET)
	self.add_child(bomb)

func find_bombs_in_range(var trigger_bomb, cur_bomb = trigger_bomb, exceptions = []):
	# Cast rays to determine collisions with other bombs, and do that recursively to find the complete chain reaction
	var space_state = global.level.get_world_2d().get_direct_space_state()
	if exceptions.empty():
		exceptions.append(trigger_bomb.get_node("StaticBody2D"))
		exceptions += global.player_manager.get_children()
	var new_bombs = []
	
	for key in dir:
		var raycast = space_state.intersect_ray(cur_bomb.get_pos(), cur_bomb.get_pos() + dir[key]*cur_bomb.bomb_range*global.TILE_SIZE, exceptions)
		
		# Check first for other bombs that should be triggered
		while (!raycast.empty() and raycast.collider.get_parent() in self.get_children()):
			var bomb_found = raycast.collider.get_parent()
			trigger_bomb.chained_bombs.append(bomb_found)
			new_bombs.append(bomb_found)
			# Stop animations and timer of secondary bomb to prevent loops
			bomb_found.get_node("AnimatedSprite/TimerIdle").stop()
			bomb_found.get_node("AnimatedSprite/AnimationPlayer").stop()
			exceptions.append(raycast.collider)
			raycast = space_state.intersect_ray(cur_bomb.get_pos(), cur_bomb.get_pos() + dir[key]*cur_bomb.bomb_range*global.TILE_SIZE, exceptions)
		
		if (raycast.empty()):
			# No collision in range, so full range for the animation
			cur_bomb.anim_ranges[key] = cur_bomb.bomb_range
		elif (raycast.collider == global.tilemap_destr or raycast.collider == global.tilemap_indestr):
			# Destructible or indestructible in range, they limit the animation and should be handled differently
			var target_cell_pos = global.tilemap_destr.world_to_map(raycast.position + dir[key]*global.TILE_SIZE*0.5)
			var distance_rel = target_cell_pos - cur_bomb.cell_pos
			cur_bomb.anim_ranges[key] = dir[key].x*distance_rel.x + dir[key].y*distance_rel.y - 1
			if (raycast.collider == global.tilemap_destr):
				cur_bomb.destruct_cells.append(target_cell_pos)
			else:
				cur_bomb.indestruct_cells.append(target_cell_pos)
		else:
			print("Warning: Unexpected collision with '", raycast.collider, "' for the bomb explosion.")
	
	for bomb in new_bombs:
		find_bombs_in_range(trigger_bomb, bomb, exceptions)

func play_animation(var trigger_bomb):
	for bomb in [trigger_bomb] + trigger_bomb.chained_bombs:
		# Display flame "branches" depending on their length
		for key in dir:
			if (bomb.anim_ranges[key] != 0):
				var xflip = dir[key].x > 0
				var yflip = dir[key].x + dir[key].y > 0
				var transpose = dir[key].y != 0
				if (bomb.anim_ranges[key] == 1):
					var pos = bomb.cell_pos + dir[key]
					bomb.flame_cells.append(pos)
					global.tilemap_destr.set_cell(pos.x, pos.y, FLAME_SMALL, xflip, yflip, transpose)
				else:
					for i in range(1, bomb.anim_ranges[key] + 1):
						var pos = bomb.cell_pos + i*dir[key]
						bomb.flame_cells.append(pos)
						var tile_index
						if (i == bomb.anim_ranges[key]):
							tile_index = FLAME_LONG_END
						else:
							tile_index = FLAME_LONG_MIDDLE
						global.tilemap_destr.set_cell(pos.x, pos.y, tile_index, xflip, yflip, transpose)
	
		for pos in bomb.destruct_cells:
			# "Exploding" tile ID should be normal tile ID + 1
			global.tilemap_destr.set_cell(pos.x, pos.y, global.tilemap_destr.get_cell(pos.x, pos.y) + 1)
	
	for bomb in [trigger_bomb] + trigger_bomb.chained_bombs:
		# Display "source" flame tile where the bomb is, and hide bomb
		bomb.get_node("AnimatedSprite").hide()
		bomb.flame_cells.append(bomb.cell_pos)
		global.tilemap_destr.set_cell(bomb.cell_pos.x, bomb.cell_pos.y, FLAME_SOURCE)
	
	# Start timer that should trigger the cleanup of the animation
	trigger_bomb.get_node("AnimatedSprite/TimerAnim").start()

func stop_animation(var trigger_bomb):
	for bomb in [trigger_bomb] + trigger_bomb.chained_bombs:
		for pos in bomb.flame_cells:
			global.tilemap_destr.set_cell(pos.x, pos.y, -1)
		for pos in bomb.destruct_cells:
			global.tilemap_destr.set_cell(pos.x, pos.y, -1)

func bomb_on_tile(var tile_pos):
	for bomb in get_children():
		if (bomb.cell_pos == tile_pos):
			return true
	return false

func _ready():
	# Initialisations
	global = get_node("/root/global")
