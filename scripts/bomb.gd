extends Node2D

# Nodes
var global
var player

# Member variables
var cell_pos				# Bomb tilemap coordinates
var bomb_range				# Range of the bomb explosion

var chained_bombs = []		# Bombs triggered by the chain reaction
var anim_ranges = {}		# Explosion range for each direction
var flame_cells = []		# Coordinates of the cells with flame animation
var destruct_cells = []		# Coordinates of the destructible cells in range
var indestruct_cells = []	# Coordinates of the destructible cells in range

func _on_TimerIdle_timeout():
	self.get_node("AnimatedSprite/AnimationPlayer").play("countdown")

func _on_AnimationPlayer_finished():
	# Find collisions and act accordingly
	global.bomb_manager.find_chain_and_collisions(self)
	# Free bomb spots for the players as soon as they are triggered
	for bomb in self.chained_bombs:
		bomb.player.active_bombs -= 1
	self.player.active_bombs -= 1
	# Register as exploding bomb
	global.bomb_manager.exploding_bombs.append(self)
	# Play animation corresponding to the explosion of self and its chain reaction
	global.bomb_manager.play_animation(self)

func _on_TimerAnim_timeout():
	global.bomb_manager.stop_animation(self)
	
	# Free chained bombs and trigger bomb
	for bomb in self.chained_bombs:
		bomb.player.bomb_collision_exceptions.erase(bomb)
		bomb.queue_free()
	self.player.bomb_collision_exceptions.erase(self)
	global.bomb_manager.exploding_bombs.erase(self)
	self.queue_free()

func _ready():
	# Initialisations
	global = get_node("/root/global")
