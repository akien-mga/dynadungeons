extends Node2D

### Nodes
var global
var level
var player

### Constants
const dir = { "up": Vector2(0,-1),
              "down": Vector2(0,1),
              "left": Vector2(-1,0),
              "right": Vector2(1,0) }
# Tile IDs in the tilemap
const FLAME_SOURCE = 8
const FLAME_SMALL = 9
const FLAME_LONG_MIDDLE = 10
const FLAME_LONG_END = 11
const SLIDE_SPEED = 8		# How fast a bomb slides when kicked

### Member variables
var cell_pos = Vector2()	# Bomb tilemap coordinates
var bomb_range				# Range of the bomb explosion
var counter = 1				# Counter for flame animation

var exploding = false		# Is the bomb exploding?
var chained_bombs = []		# Bombs triggered by the chain reaction
var anim_ranges = {}		# Explosion range for each direction
var flame_cells = []		# Coordinates and orientation of the cells with flame animation
var destruct_cells = []		# Coordinates of the destructible cells in range
var indestruct_cells = []	# Coordinates of the destructible cells in range

var slide_dir = Vector2()	# Direction in which to slide upon kick
var target_cell = Vector2()	# The tilemap coordinates of the target

### Helper functions

func get_cell_pos():
	return cell_pos

func update_cell_pos():
	"""Save the tilemap position to access it with less calculations involved
	The drawback being that this function must be called each time the bomb changes cell
	"""
	cell_pos = level.world_to_map(self.get_pos())

func set_pos_and_update(abs_pos):
	"""Set the absolute position and update the discrete tilemap position"""
	set_pos(abs_pos)
	update_cell_pos()

### Main logic

func find_chain_and_collisions(trigger_bomb, exceptions = []):
	"""Cast rays to determine collisions with other bombs, and do that recursively to find the complete chain reaction
	When a collider is found, it is handled based on its type
	"""
	# Initialise space state for raycasting and collision exceptions
	var space_state = level.get_world_2d().get_direct_space_state()
	if exceptions.empty():
		exceptions.append(trigger_bomb.get_node("StaticBody2D"))
		exceptions += level.player_manager.get_children()
	# Array of newly triggered bombs for which collisions have to be checked
	var new_bombs = []
	
	for key in dir:
		# Cast a ray between the bomb and its maximal range
		var raycast = space_state.intersect_ray(self.get_pos(), self.get_pos() + dir[key]*self.bomb_range*global.TILE_SIZE, exceptions)
		
		# Check first for other bombs in range that would be chain-triggered
		while (!raycast.empty() and raycast.collider.get_parent() in level.bomb_manager.get_children()):
			var bomb_found = raycast.collider.get_parent()
			if (not bomb_found.exploding):
				# Register the bomb found as a chained bomb of the originally triggered bomb
				trigger_bomb.chained_bombs.append(bomb_found)
				new_bombs.append(bomb_found)
				# Stop animations and timer of secondary bomb to prevent loops
				bomb_found.get_node("AnimatedSprite/TimerIdle").stop()
				bomb_found.get_node("AnimatedSprite/AnimationPlayer").stop()
			# Add found bomb as an exception and cast a new ray to check for other targets in range of the triggered bomb
			exceptions.append(raycast.collider)
			raycast = space_state.intersect_ray(self.get_pos(), self.get_pos() + dir[key]*self.bomb_range*global.TILE_SIZE, exceptions)
		
		if (raycast.empty()):
			# No collision in range, so full range for the animation
			self.anim_ranges[key] = self.bomb_range
		elif (raycast.collider.get_parent() == level.map_manager):
			# Destructible, indestructible or collectible (dummy collider) in range, they limit the animation
			var target_cell_pos = level.world_to_map(raycast.position + dir[key]*global.TILE_SIZE*0.5)
			var distance_rel = target_cell_pos - get_cell_pos()
			self.anim_ranges[key] = dir[key].x*distance_rel.x + dir[key].y*distance_rel.y - 1
			if (raycast.collider == level.tilemap_destr and not target_cell_pos in trigger_bomb.destruct_cells):
				# Register target cell to be destroyed
				trigger_bomb.destruct_cells.append(target_cell_pos)
			elif (raycast.collider == level.tilemap_indestr and not target_cell_pos in trigger_bomb.indestruct_cells):
				# Register indestructible target cell
				# TODO: Currently useless, but the idea would be to animate the tile with flames on the edge
				trigger_bomb.indestruct_cells.append(target_cell_pos)
			else:
				# Should be a dummy collider under a collectible
				# Remove the dummy collider
				level.tilemap_dummy.set_cell(target_cell_pos.x, target_cell_pos.y, -1)
				# Remove the corresponding collectible(s)
				for collectible in level.collectible_manager.get_children():
					if (level.world_to_map(collectible.get_pos()) == target_cell_pos):
						collectible.destroy()
		else:
			print("Warning: Unexpected collision with '", raycast.collider, "' for the bomb explosion.")
	
	# Run this function on the newly triggered bombs to build the complete chained explosion
	for bomb in new_bombs:
		bomb.find_chain_and_collisions(trigger_bomb, exceptions)

func push_dir(direction):
	"""Let the bomb slide in the specified direction until it hits an obstacle"""
	
	# Initialise the space state and cast a ray to check for an obstacle in the adjacent tile
	var space_state = level.get_world_2d().get_direct_space_state()
	var raycast = space_state.intersect_ray(level.map_to_world(get_cell_pos()), level.map_to_world(get_cell_pos() + direction), [ get_node("StaticBody2D") ])
	
	# If there is no obstacle, start sliding and use _fixed_process to handle it
	if (raycast.empty()):
		# Save the slide direction and target cell for use in _fixed_process
		slide_dir = direction
		target_cell = get_cell_pos() + slide_dir
		set_fixed_process(true)
		level.play_sound("push" + str(randi() % 2 + 1))

### Explosion animation and logic

func start_animation():
	"""Start displaying the explosion animation for all bombs triggered by this node
	The animation does not use an animation player, but simply changes the tile displayed in tilemap_destr,
	resulting in a somewhat messy but flexible behaviour (to handle branches of various lengths, overlaps, etc.)
	"""
	for bomb in [self] + self.chained_bombs:
		# Display flame "branches" depending on their length
		for key in dir:
			if (bomb.anim_ranges[key] != 0):
				# Handle branch orientation based on the direction
				var xflip = dir[key].x > 0
				var yflip = dir[key].x + dir[key].y > 0
				var transpose = dir[key].y != 0
				# Change tiles visuals and register their characteristics for later cleaning
				if (bomb.anim_ranges[key] == 1):
					# Display a "small" flame
					var pos = bomb.get_cell_pos() + dir[key]
					bomb.flame_cells.append({'pos': pos, 'tile': FLAME_SMALL, 'xflip': xflip, 'yflip': yflip, 'transpose': transpose})
					level.tilemap_destr.set_cell(pos.x, pos.y, FLAME_SMALL, xflip, yflip, transpose)
				else:
					# Fill intermediate positions with "middle" flames, and end tile with "end" flame
					for i in range(1, bomb.anim_ranges[key] + 1):
						var pos = bomb.get_cell_pos() + i*dir[key]
						var tile_index
						if (i == bomb.anim_ranges[key]):
							tile_index = FLAME_LONG_END
						else:
							tile_index = FLAME_LONG_MIDDLE
						bomb.flame_cells.append({'pos': pos, 'tile': tile_index, 'xflip': xflip, 'yflip': yflip, 'transpose': transpose})
						level.tilemap_destr.set_cell(pos.x, pos.y, tile_index, xflip, yflip, transpose)
	
	for pos in self.destruct_cells:
		# "Exploding" tile ID should be normal tile ID + 1
		level.tilemap_destr.set_cell(pos.x, pos.y, level.tilemap_destr.get_cell(pos.x, pos.y) + 1)
	
	# Display "source" flame tile where the bomb is, and hide bomb
	# This is done in a separate loop to make sure source flames override branches
	for bomb in [self] + self.chained_bombs:
		bomb.get_node("AnimatedSprite").hide()
		bomb.exploding = true
		level.tilemap_destr.set_cell(bomb.get_cell_pos().x, bomb.get_cell_pos().y, FLAME_SOURCE)
	
	# Play explosion sound
	level.play_sound("explosion" + str(randi() % 2 + 1))
	
	# Start timer that should trigger the cleanup of the animation
	self.get_node("AnimatedSprite/TimerAnim").start()

func update_animation():
	"""Make the explosion animation loop over a set of sprites for a livelier animation"""
	
	# Update "branch" tiles first
	for bomb in [self] + self.chained_bombs:
		for cell_dict in bomb.flame_cells:
			level.tilemap_destr.set_cell(cell_dict.pos.x, cell_dict.pos.y, cell_dict.tile + 4*(self.counter % 3), cell_dict.xflip, cell_dict.yflip, cell_dict.transpose)
	
	# Update "source" tiles afterwards to ensure a nice overlap
	for bomb in [self] + self.chained_bombs:
		level.tilemap_destr.set_cell(bomb.get_cell_pos().x, bomb.get_cell_pos().y, FLAME_SOURCE + 4*(self.counter % 3))

func stop_animation():
	"""Stop the explosion animation (therefore removing the flame tiles from tilemap_destr)
	and spawn collectibles randomly where destructible objects were present"""
	for bomb in [self] + self.chained_bombs:
		for cell_dict in bomb.flame_cells:
			level.tilemap_destr.set_cell(cell_dict.pos.x, cell_dict.pos.y, -1)
		level.tilemap_destr.set_cell(bomb.get_cell_pos().x, bomb.get_cell_pos().y, -1)
		
		# Spawn collectibles randomly based on the rates for each type
		for pos in bomb.destruct_cells:
			# Spawn something if we pass the global rate test
			if (randi() % 100 < global.COLLECTIBLE_RATE):
				var collectible = global.collectible_scene.instance()
				# Determine the collectible type based on their individual frequencies
				# by picking a number in range of the cumulated frequencies, and then checking
				# each interval until the corresponding one is found
				var index = randi() % global.collectibles.sum_freq
				var sum = global.collectibles.freq[0]
				for i in range(global.collectibles.types.size()):
					if index <= sum:
						index = i
						break
					sum += global.collectibles.freq[i+1]
				collectible.effect = global.collectibles.types[index]
				collectible.set_pos(level.map_to_world(pos))
				level.collectible_manager.add_child(collectible)
				# Add a dummy collider under the collectible
				level.tilemap_dummy.set_cell(pos.x, pos.y, 0)
			level.tilemap_destr.set_cell(pos.x, pos.y, -1)

### Process

func _on_TimerIdle_timeout():
	self.get_node("AnimatedSprite/AnimationPlayer").play("countdown")

func trigger_explosion():
	"""Main process called when the bombs reaches its timeout. This function stops the bomb if slides,
	checks for collisions, removes bombs from their player parent and starts the animation.
	"""
	
	# Stop potential sliding movement
	set_fixed_process(false)
	# Find collisions and act accordingly
	find_chain_and_collisions(self)
	# Free bomb spots for the players as soon as they are triggered
	for bomb in self.chained_bombs + [ self ]:
		if (bomb.player != null):
			bomb.player.active_bombs.erase(bomb)
		# Make sure the bomb is no longer in the collision_exceptions of a player
		for any_player in level.player_manager.get_children():
			if bomb in any_player.collision_exceptions:
				any_player.remove_collision_exception_with(self.get_node("StaticBody2D"))
				any_player.collision_exceptions.erase(bomb)

	# Register as exploding bomb
	level.exploding_bombs.append(self)
	# Play animation corresponding to the explosion of self and its chain reaction
	start_animation()

func _on_TimerAnim_timeout():
	"""Handle the update of the explosion animation and the freeing of the exploded bomb nodes"""
	if (counter < 5):
		update_animation()
		counter += 1
		get_node("AnimatedSprite/TimerAnim").start()
	else:
		# Stop the animation before freeing the chained and trigger bombs
		stop_animation()
		# Free chained bombs and trigger bomb after removing their owner's collision exception
		level.exploding_bombs.erase(self)
		for bomb in self.chained_bombs:
			if (bomb.player != null):
				bomb.player.collision_exceptions.erase(bomb)
			bomb.queue_free()
		if (self.player != null):
			self.player.collision_exceptions.erase(self)
		self.queue_free()

func _fixed_process(delta):
	"""Handle the potential sliding movement of the bomb if it has been kicked"""
	
	# Calculate the candidate position of the bomb for the next frame
	# FIXME: Why the 0.5 btw?
	var new_pos = get_pos() + slide_dir*SLIDE_SPEED*0.5*global.TILE_SIZE*delta
	# Check if the bomb is past its target cell
	if (slide_dir.dot(level.map_to_world(target_cell) - new_pos) < 0):
		set_pos_and_update(level.map_to_world(target_cell))
		
		# The bomb reached its target, check if it can continue to slide to the next tile
		var space_state = level.get_world_2d().get_direct_space_state()
		var raycast = space_state.intersect_ray(level.map_to_world(get_cell_pos()), level.map_to_world(get_cell_pos() + slide_dir), [ get_node("StaticBody2D") ])
		
		if (raycast.empty()):
			target_cell = get_cell_pos() + slide_dir
		else:
			set_fixed_process(false)
			return
	else:
		set_pos(new_pos)
	
	# Check currently exploding bombs that might trigger this one
	for trigger_bomb in level.exploding_bombs:
		for bomb in [ trigger_bomb ] + trigger_bomb.chained_bombs:
			for cell_dict in bomb.flame_cells:
				if (self.get_cell_pos() == cell_dict.pos):
					# Stop animations and timer
					get_node("AnimatedSprite/TimerIdle").stop()
					get_node("AnimatedSprite/AnimationPlayer").stop()
					trigger_explosion()
					return

### Initialisation

func _ready():
	global = get_node("/root/global")
	level = get_tree().get_root().get_node("World/Level")
