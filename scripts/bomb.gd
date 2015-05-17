extends Node2D

# Nodes
var global
var player

# Constants
const dir = { "up": Vector2(0,-1),
              "down": Vector2(0,1),
              "left": Vector2(-1,0),
              "right": Vector2(1,0) }
const FLAME_SOURCE = 8
const FLAME_SMALL = 9
const FLAME_LONG_MIDDLE = 10
const FLAME_LONG_END = 11

# Member variables
var cell_pos				# Bomb tilemap coordinates
var bomb_range				# Range of the bomb explosion
var counter = 1

var chained_bombs = []		# Bombs triggered by the chain reaction
var anim_ranges = {}		# Explosion range for each direction
var flame_cells = []		# Coordinates and orientation of the cells with flame animation
var destruct_cells = []		# Coordinates of the destructible cells in range
var indestruct_cells = []	# Coordinates of the destructible cells in range


func find_chain_and_collisions(var trigger_bomb, exceptions = []):
	# Cast rays to determine collisions with other bombs, and do that recursively to find the complete chain reaction
	var space_state = global.level.get_world_2d().get_direct_space_state()
	if exceptions.empty():
		exceptions.append(trigger_bomb.get_node("StaticBody2D"))
		exceptions += global.player_manager.get_children()
	var new_bombs = []
	
	for key in dir:
		var raycast = space_state.intersect_ray(self.get_pos(), self.get_pos() + dir[key]*self.bomb_range*global.TILE_SIZE, exceptions)
		
		# Check first for other bombs that should be triggered
		while (!raycast.empty() and raycast.collider.get_parent() in global.bomb_manager.get_children()):
			var bomb_found = raycast.collider.get_parent()
			trigger_bomb.chained_bombs.append(bomb_found)
			new_bombs.append(bomb_found)
			# Stop animations and timer of secondary bomb to prevent loops
			bomb_found.get_node("AnimatedSprite/TimerIdle").stop()
			bomb_found.get_node("AnimatedSprite/AnimationPlayer").stop()
			exceptions.append(raycast.collider)
			raycast = space_state.intersect_ray(self.get_pos(), self.get_pos() + dir[key]*self.bomb_range*global.TILE_SIZE, exceptions)
		
		if (raycast.empty()):
			# No collision in range, so full range for the animation
			self.anim_ranges[key] = self.bomb_range
		elif (raycast.collider == global.tilemap_destr or raycast.collider == global.tilemap_indestr):
			# Destructible or indestructible in range, they limit the animation and should be handled differently
			var target_cell_pos = global.tilemap_destr.world_to_map(raycast.position + dir[key]*global.TILE_SIZE*0.5)
			var distance_rel = target_cell_pos - self.cell_pos
			self.anim_ranges[key] = dir[key].x*distance_rel.x + dir[key].y*distance_rel.y - 1
			if (raycast.collider == global.tilemap_destr):
				self.destruct_cells.append(target_cell_pos)
			else:
				self.indestruct_cells.append(target_cell_pos)
		else:
			print("Warning: Unexpected collision with '", raycast.collider, "' for the bomb explosion.")
	
	for bomb in new_bombs:
		bomb.find_chain_and_collisions(trigger_bomb, exceptions)

func start_animation():
	for bomb in [self] + self.chained_bombs:
		# Display flame "branches" depending on their length
		for key in dir:
			if (bomb.anim_ranges[key] != 0):
				var xflip = dir[key].x > 0
				var yflip = dir[key].x + dir[key].y > 0
				var transpose = dir[key].y != 0
				if (bomb.anim_ranges[key] == 1):
					var pos = bomb.cell_pos + dir[key]
					bomb.flame_cells.append({'pos': pos, 'tile': FLAME_SMALL, 'xflip': xflip, 'yflip': yflip, 'transpose': transpose})
					global.tilemap_destr.set_cell(pos.x, pos.y, FLAME_SMALL, xflip, yflip, transpose)
				else:
					for i in range(1, bomb.anim_ranges[key] + 1):
						var pos = bomb.cell_pos + i*dir[key]
						var tile_index
						if (i == bomb.anim_ranges[key]):
							tile_index = FLAME_LONG_END
						else:
							tile_index = FLAME_LONG_MIDDLE
						bomb.flame_cells.append({'pos': pos, 'tile': tile_index, 'xflip': xflip, 'yflip': yflip, 'transpose': transpose})
						global.tilemap_destr.set_cell(pos.x, pos.y, tile_index, xflip, yflip, transpose)
	
		for pos in bomb.destruct_cells:
			# "Exploding" tile ID should be normal tile ID + 1
			global.tilemap_destr.set_cell(pos.x, pos.y, global.tilemap_destr.get_cell(pos.x, pos.y) + 1)
	
	# Display "source" flame tile where the bomb is, and hide bomb
	# This is done in a separate loop to make sure source flames override branches
	for bomb in [self] + self.chained_bombs:
		bomb.get_node("AnimatedSprite").hide()
		global.tilemap_destr.set_cell(bomb.cell_pos.x, bomb.cell_pos.y, FLAME_SOURCE)
	
	# Start timer that should trigger the cleanup of the animation
	self.get_node("AnimatedSprite/TimerAnim").start()

func update_animation():
	# Update "branch" tiles first
	for bomb in [self] + self.chained_bombs:
		for cell_dict in bomb.flame_cells:
			global.tilemap_destr.set_cell(cell_dict.pos.x, cell_dict.pos.y, cell_dict.tile + 4*(self.counter % 3), cell_dict.xflip, cell_dict.yflip, cell_dict.transpose)
	
	# Update "source" tiles afterwards to ensure a nice overlap
	for bomb in [self] + self.chained_bombs:
		global.tilemap_destr.set_cell(bomb.cell_pos.x, bomb.cell_pos.y, FLAME_SOURCE + 4*(self.counter % 3))

func stop_animation():
	for bomb in [self] + self.chained_bombs:
		for cell_dict in bomb.flame_cells:
			global.tilemap_destr.set_cell(cell_dict.pos.x, cell_dict.pos.y, -1)
		global.tilemap_destr.set_cell(bomb.cell_pos.x, bomb.cell_pos.y, -1)
		for pos in bomb.destruct_cells:
			# Random chance to add a random pickup
			if (randi() % 100 < global.COLLECTIBLE_RATE):
				var collectible = global.collectible_scene.instance()
				var index = randi() % global.collectibles.sum_freq
				var sum = global.collectibles.freq[0]
				for i in range(global.collectibles.types.size()):
					if index <= sum:
						index = i
						break
					sum += global.collectibles.freq[i+1]
				collectible.effect = global.collectibles.types[index]
				collectible.set_pos(global.map_to_world(pos))
				global.collectible_manager.add_child(collectible)
			global.tilemap_destr.set_cell(pos.x, pos.y, -1)

func _on_TimerIdle_timeout():
	self.get_node("AnimatedSprite/AnimationPlayer").play("countdown")

func _on_AnimationPlayer_finished():
	# Find collisions and act accordingly
	find_chain_and_collisions(self)
	# Free bomb spots for the players as soon as they are triggered
	for bomb in self.chained_bombs:
		if (bomb.player != null):
			bomb.player.active_bombs.erase(bomb)
	if (self.player != null):
		self.player.active_bombs.erase(self)
	# Register as exploding bomb
	global.exploding_bombs.append(self)
	# Play animation corresponding to the explosion of self and its chain reaction
	start_animation()

func _on_TimerAnim_timeout():
	if (counter < 5):
		update_animation()
		counter += 1
		get_node("AnimatedSprite/TimerAnim").start()
	else:
		stop_animation()
		# Free chained bombs and trigger bomb
		for bomb in self.chained_bombs:
			if (bomb.player != null):
				bomb.player.collision_exceptions.erase(bomb)
			bomb.queue_free()
		if (self.player != null):
			self.player.collision_exceptions.erase(self)
		global.exploding_bombs.erase(self)
		self.queue_free()

func _ready():
	# Initialisations
	global = get_node("/root/global")
