extends Node2D
class_name CombatantNode

enum Role {
	ALLY = 0,
	ENEMY = 1
}

class ChosenMove:
	var move: Move = null
	var effectType: Move.MoveEffectType = Move.MoveEffectType.NONE
	
	func _init(i_move = null, i_effectType = Move.MoveEffectType.NONE):
		move = i_move
		effectType = i_effectType

signal toggled(button_pressed: bool, combatantNode: CombatantNode)
signal details_clicked(combatantNode: CombatantNode)

@export_category("CombatantNode - Details")
@export var combatant: Combatant = null
@export var initialCombatantLv: int = 1
@export var role: Role = Role.ALLY
@export var leftSide: bool = false
@export var spriteFacesRight: bool = false
@export var battlePosition: String = ''
@export var unlockSurgeRequirements: StoryRequirements = null

@export_category("CombatantNode - Movement")
@export var allyTeamMarker: Marker2D
@export var enemyTeamMarker: Marker2D
@export var battleController: Node2D
# NOTE: if this is of type BattleController, then the SFX Button scene breaks.... no joke. WHYYYYYYY??

const ANIMATE_MOVE_SPEED = 90
const moveSpriteScene = preload('res://prefabs/battle/move_sprite.tscn')
var tmpAllCombatantNodes: Array[CombatantNode] = []
var animateTween: Tween = null
var hpDrainTween: Tween = null
var fadeOutTween: Tween = null
var returnToPos: Vector2 = Vector2()
var playHitQueued: ParticlePreset = null
var playHitTimingDelay: float = 0
var playHitEnabled: bool = false
var playParticlesQueued: ParticlePreset = null
var playParticlesTimingDelay: float = 0
var playMoveSpritesQueued: Array[MoveAnimSprite] = []
var playedMoveSprites: int = 0
var moveSpriteTargets: Array[CombatantNode] = []
var moveSpritesCallback: Callable = Callable()

@onready var hpTag: Panel = get_node('HPTag')
@onready var lvText: RichTextLabel = get_node('HPTag/LvText')
@onready var hpText: RichTextLabel = get_node('HPTag/LvText/HPText')
@onready var hpProgressBar: TextureProgressBar = get_node('HPTag/LvText/HPProgressBar')
@onready var orbDisplay: OrbDisplay = get_node('HPTag/OrbDisplay')
@onready var spriteContainer: Node2D = get_node('SpriteContainer')
@onready var animatedSprite: AnimatedSprite2D = get_node('SpriteContainer/AnimatedSprite')
@onready var selectCombatantBtn: TextureButton = get_node('SelectCombatantBtn')
@onready var behindParticleContainer: Node2D = get_node('SpriteContainer/BehindParticleContainer')
@onready var surgeParticles: Particles = get_node('SpriteContainer/BehindParticleContainer/SurgeParticleEmitter')
@onready var behindParticles: Particles = get_node('SpriteContainer/BehindParticleContainer/BehindParticleEmitter')
@onready var frontParticleContainer: Node2D = get_node('SpriteContainer/FrontParticleContainer')
@onready var frontParticles: Particles = get_node('SpriteContainer/FrontParticleContainer/FrontParticleEmitter')
@onready var hitParticles: Particles = get_node('SpriteContainer/FrontParticleContainer/HitParticleEmitter')
@onready var shardParticles: Particles = get_node('SpriteContainer/FrontParticleContainer/ShardParticleEmitter')
@onready var onAttackMarker: Marker2D = get_node('OnAttackPos')
@onready var onAssistMarker: Marker2D = get_node('OnAssistPos')

# Called when the node enters the scene tree for the first time.
func _ready():
	returnToPos = global_position
	if battleController != null:
		battleController.combatant_finished_moving.connect(_combatant_finished_moving)
		battleController.combatants_play_hit.connect(_combatants_play_hit)
		battleController.combatant_finished_animating.connect(_combatant_finished_animating)
	orbDisplay.alignment = BoxContainer.ALIGNMENT_END if leftSide else BoxContainer.ALIGNMENT_BEGIN

func load_combatant_node():
	if not is_alive():
		visible = false
	else:
		visible = true
		if combatant.statChanges == null:
			combatant.statChanges = StatChanges.new()
		animatedSprite.sprite_frames = combatant.spriteFrames
		if combatant.spriteFrames == null:
			animatedSprite.sprite_frames = load("res://graphics/animations/a_player.tres") # TEMP prevent crashing
		animatedSprite.play('stand')
		animatedSprite.flip_h = (leftSide and not spriteFacesRight) or (not leftSide and spriteFacesRight)
		update_select_btn(false)
		hpProgressBar.max_value = combatant.stats.maxHp
		hpProgressBar.value = combatant.currentHp
		hpProgressBar.tint_progress = Combatant.get_hp_bar_color(combatant.currentHp, combatant.stats.maxHp)
		update_hp_tag()
		
		behindParticleContainer.scale.x = get_behind_particle_scale()
		behindParticleContainer.scale.y = behindParticleContainer.scale.x
		
		frontParticleContainer.scale.x = get_in_front_particle_scale()
		frontParticleContainer.scale.y = frontParticleContainer.scale.x
		surgeParticles.set_make_particles(false)
		behindParticles.set_make_particles(false)
		frontParticles.set_make_particles(false)
		hitParticles.set_make_particles(false)
		shardParticles.set_make_particles(false)
		
		# nudge the attack marker away from sprite by any amount over 16 wide
		if onAttackMarker.position.x < position.x:
			onAttackMarker.position.x -= (combatant.maxSize.x - 16) / 2
		elif onAttackMarker.position.x > position.x:
			onAttackMarker.position.x += (combatant.maxSize.x - 16) / 2
		
		# nudge the assist marker away from sprite by any amount over 16 tall
		if onAssistMarker.position.y < position.y:
			onAssistMarker.position.y -= (combatant.maxSize.y - 16) / 2
		elif onAssistMarker.position.y > position.y:
			onAssistMarker.position.y += (combatant.maxSize.y - 16) / 2

func get_in_front_particle_scale() -> float:
		# scale of particles in front of combatant: 1*, plus 0.25 for every 16 px larger
	return 1 + round(max(0, max(combatant.maxSize.x, combatant.maxSize.y) - 16) / 16) / 4

func get_behind_particle_scale() -> float:
	# scale of particles behind combatant: 1.5*, plus 0.25 for every 16 px larger
	return 1.5 + round(max(0, max(combatant.maxSize.x, combatant.maxSize.y) - 16) / 16) / 4

func update_hp_tag():
	if not is_alive():
		if visible and fadeOutTween == null:
			fadeOutTween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
			fadeOutTween.tween_property(self, 'modulate', Color(0, 0, 0, 0), 0.75)
			fadeOutTween.finished.connect(_fade_out_finished)
			# TODO: play death sfx here...
		else:
			return
	
	hpTag.visible = true
	lvText.text = 'Lv ' + String.num(combatant.stats.level)
	lvText.size.x = len(lvText.text) * 13 # about 13 pixels per character
	hpText.text = TextUtils.num_to_comma_string(combatant.currentHp) + ' / ' + TextUtils.num_to_comma_string(combatant.stats.maxHp)
	#hpText.size.x = len(hpText.text) * 13 - 10 # magic number
	hpProgressBar.max_value = combatant.stats.maxHp
	if hpProgressBar.value != combatant.currentHp:
		if hpDrainTween != null and hpDrainTween.is_valid():
			hpDrainTween.kill()
		hpDrainTween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		hpDrainTween.parallel().tween_property(hpProgressBar, 'value', combatant.currentHp, 1)
		hpDrainTween.parallel().tween_property(hpProgressBar, 'tint_progress', Combatant.get_hp_bar_color(combatant.currentHp, combatant.stats.maxHp), 1)
		hpDrainTween.finished.connect(_on_hp_drain_tween_finished)
	
	#hpTag.size.x = (lvText.size.x + hpText.size.x) * lvText.scale.x + 8 # magic number
	if leftSide:
		hpTag.position = Vector2(-1 * hpTag.size.x - selectCombatantBtn.size.x * 0.5 - 4, -0.5 * hpTag.size.y)
	else:
		hpTag.position = Vector2(selectCombatantBtn.size.x * 0.5 + 4, -0.5 * hpTag.size.y)
	
	#if ((unlockSurgeRequirements == null or unlockSurgeRequirements.is_valid()) and leftSide) or ((Combatant.useSurgeReqs == null or Combatant.useSurgeReqs.is_valid()) and not leftSide):
		#orbDisplay.visible = true
	orbDisplay.currentOrbs = combatant.orbs
	orbDisplay.update_orb_display()
	#else:
		#orbDisplay.visible = false

func update_select_btn(showing: bool, disable: bool = false):
	if not is_alive():
		return
		
	selectCombatantBtn.visible = showing
	selectCombatantBtn.disabled = disable
	update_select_btn_texture()
	
	selectCombatantBtn.size = combatant.maxSize + Vector2(8, 8) # set size of selecting button to sprite size + 8px
	selectCombatantBtn.position = -0.5 * selectCombatantBtn.size # center button

func update_select_btn_texture():
	if selectCombatantBtn.disabled:
		if is_selected():
			selectCombatantBtn.texture_disabled = selectCombatantBtn.texture_pressed
		else:
			selectCombatantBtn.texture_disabled = selectCombatantBtn.texture_normal

func focus_select_btn():
	selectCombatantBtn.grab_focus()

func set_buttons_left_neighbor(control: Control):
	selectCombatantBtn.focus_neighbor_left = selectCombatantBtn.get_path_to(control)
	control.focus_neighbor_right = control.get_path_to(selectCombatantBtn)
	
func set_buttons_right_neighbor(control: Control):
	selectCombatantBtn.focus_neighbor_right = selectCombatantBtn.get_path_to(control)
	control.focus_neighbor_left = control.get_path_to(selectCombatantBtn)
	
func set_buttons_top_neighbor(control: Control):
	selectCombatantBtn.focus_neighbor_top = selectCombatantBtn.get_path_to(control)
	control.focus_neighbor_bottom = control.get_path_to(selectCombatantBtn)
	
func set_buttons_bottom_neighbor(control: Control):
	selectCombatantBtn.focus_neighbor_bottom = selectCombatantBtn.get_path_to(control)
	control.focus_neighbor_top = control.get_path_to(selectCombatantBtn)

func set_focus_left_combatant_node_neighbor(combatantNode: CombatantNode):
	selectCombatantBtn.focus_neighbor_left = selectCombatantBtn.get_path_to(combatantNode.selectCombatantBtn)
	combatantNode.selectCombatantBtn.focus_neighbor_right = combatantNode.selectCombatantBtn.get_path_to(selectCombatantBtn)

func set_focus_right_combatant_node_neighbor(combatantNode: CombatantNode):
	selectCombatantBtn.focus_neighbor_right = selectCombatantBtn.get_path_to(combatantNode.selectCombatantBtn)
	combatantNode.selectCombatantBtn.focus_neighbor_left = combatantNode.selectCombatantBtn.get_path_to(selectCombatantBtn)
	
func set_focus_bottom_combatant_node_neighbor(combatantNode: CombatantNode):
	selectCombatantBtn.focus_neighbor_bottom = selectCombatantBtn.get_path_to(combatantNode.selectCombatantBtn)
	combatantNode.selectCombatantBtn.focus_neighbor_top = combatantNode.selectCombatantBtn.get_path_to(selectCombatantBtn)
	
func set_focus_top_combatant_node_neighbor(combatantNode: CombatantNode):
	selectCombatantBtn.focus_neighbor_top = selectCombatantBtn.get_path_to(combatantNode.selectCombatantBtn)
	combatantNode.selectCombatantBtn.focus_neighbor_bottom = combatantNode.selectCombatantBtn.get_path_to(selectCombatantBtn)
	
func set_selected(selected: bool = true):
	selectCombatantBtn.button_pressed = selected
	update_select_btn_texture()
	
func is_selected() -> bool:
	return selectCombatantBtn.button_pressed

func play_animation(animationName: String):
	if animationName == '':
		animatedSprite.stop()
		return
	animatedSprite.play(animationName)

func tween_to(pos: Vector2):
	if combatant.maxSize.x > 16:
		if pos.x > global_position.x:
			pos.x -= (combatant.maxSize.x - 16) / 2
		else:
			pos.x += (combatant.maxSize.x - 16) / 2
	
	if combatant.maxSize.y > 16:
		if pos.y > global_position.y:
			pos.y -= (combatant.maxSize.y - 16) / 2
		else:
			pos.y += (combatant.maxSize.y - 16) / 2
	
	if animateTween != null and animateTween.is_valid():
		animateTween.kill()
		global_position = returnToPos
	animateTween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	returnToPos = global_position
	var moveTime = pos.length() / ANIMATE_MOVE_SPEED
	if animatedSprite.animation != 'stand':
		# if there's an animation playing:
		moveTime = 0
		var fps = animatedSprite.sprite_frames.get_animation_speed(animatedSprite.animation)
		for frameIdx in range(animatedSprite.sprite_frames.get_frame_count(animatedSprite.animation)):
			# add (duration of frame / per-frame time) = amount of time to display this frame
			moveTime += animatedSprite.sprite_frames.get_frame_duration(animatedSprite.animation, frameIdx) / fps
		moveTime *= 0.5 #0.667 # half the time so the destination is reached for the latter half of the animation
		
	# move to target position
	animateTween.tween_property(spriteContainer, 'global_position', pos, moveTime)
	# emit that the move was completed
	animateTween.tween_callback(_on_animate_tween_target_move_finished)
	# wait
	animateTween.tween_property(spriteContainer, 'rotation', 0, 1) # will not rotate, is simply doing nothing for a beat
	# and return at a constant rate
	animateTween.finished.connect(_on_animate_tween_finished)

func tween_back_to_return_pos():
	if animateTween != null:
		animateTween.kill()
	if battleController != null:
		# plays hit particles ONLY unless the combatant really is done
		battleController.combatants_play_hit.emit()
	animateTween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	animateTween.tween_property(spriteContainer, 'global_position', returnToPos, (returnToPos - spriteContainer.global_position).length() / ANIMATE_MOVE_SPEED)
	animateTween.finished.connect(_on_combatant_tween_returned)

func play_particles(preset: ParticlePreset, delay: bool = false, timingDelay: float = 0):
	if preset == null or preset.count == 0:
		return
	
	var presetCopy: ParticlePreset = preset.duplicate(true)
	if leftSide: # particles are designed & saved as they would play on an enemy (right side)
		presetCopy.processMaterial.direction.x *= -1 # invert inital X emission direction
	
	if presetCopy.emitter == 'hit' and delay:
		playHitQueued = presetCopy
		playHitTimingDelay = timingDelay
		return
		
	if delay:
		playParticlesQueued = presetCopy
		playParticlesTimingDelay = timingDelay
	else:
		make_particles_now(presetCopy, timingDelay)

func make_particles_now(preset: ParticlePreset, timingDelay: float = 0):
	if timingDelay > 0:
		await get_tree().create_timer(timingDelay).timeout
	
	match preset.emitter:
		'surge':
			surgeParticles.preset = preset
			surgeParticles.set_make_particles(true)
		'behind':
			behindParticles.preset = preset
			behindParticles.set_make_particles(true)
		'front':
			frontParticles.preset = preset
			frontParticles.set_make_particles(true)
		'hit':
			hitParticles.preset = preset
			hitParticles.set_make_particles(true)
		'shard':
			shardParticles.preset = preset
			shardParticles.set_make_particles(true)
	SceneLoader.audioHandler.play_sfx(preset.sfx)

func play_move_sprites(moveSprites: Array[MoveAnimSprite]):
	playMoveSpritesQueued = []
	for moveAnimSprite in moveSprites:
		if moveAnimSprite.delayedUntilReposition:
			playMoveSpritesQueued.append(moveAnimSprite)
		else:
			play_move_sprite(moveAnimSprite)

func play_move_sprite(moveAnimSprite: MoveAnimSprite):
	var nodes: Array[CombatantNode] = moveSpriteTargets
	if not moveAnimSprite.onePerTarget and len(nodes) > 0:
		nodes = [moveSpriteTargets[0]]
	for node in nodes:
		var spriteNode: MoveSprite = moveSpriteScene.instantiate()
		spriteNode.user = self
		spriteNode.anim = moveAnimSprite
		spriteNode.target = node
		spriteNode.globalMarker = battleController.globalMarker
		spriteNode.userTeam = allyTeamMarker
		spriteNode.enemyTeam = enemyTeamMarker
		spriteNode.move_sprite_complete.connect(_move_sprite_complete)
		#spriteNode.call_deferred('play_sprite_animation')
		add_child(spriteNode)
		playedMoveSprites += 1

func move_animation_callback(callback: Callable):
	moveSpritesCallback = callback

func get_targetable_combatant_nodes(allCombatantNodes: Array[CombatantNode], targets: BattleCommand.Targets) -> Array[CombatantNode]:
	if targets == BattleCommand.Targets.SELF:
		return [self]
	
	var targetableList: Array[CombatantNode] = []
	for combatantNode in allCombatantNodes:
		if not combatantNode.is_alive():
			continue # skip this combatant if not alive
		if self == combatantNode and (targets == BattleCommand.Targets.ALL_EXCEPT_SELF or targets == BattleCommand.Targets.NON_SELF_ALLY):
			continue # skip user if user is not targetable
		
		if targets == BattleCommand.Targets.ALL or targets == BattleCommand.Targets.ALL_EXCEPT_SELF:
			targetableList.append(combatantNode)
		else:
			var targetRole: CombatantNode.Role = combatantNode.role
			if ((targets == BattleCommand.Targets.ALL_ALLIES or targets == BattleCommand.Targets.ALLY or targets == BattleCommand.Targets.NON_SELF_ALLY) and targetRole == role) or \
					((targets == BattleCommand.Targets.ALL_ENEMIES or targets == BattleCommand.Targets.ENEMY) and targetRole != role):
				targetableList.append(combatantNode)
	return targetableList

func get_command(combatantNodes: Array[CombatantNode]):
	if combatant.command == null and is_alive():
		var chosenMove: ChosenMove = ai_pick_move(combatantNodes)
		if chosenMove.effectType == Move.MoveEffectType.BOTH:
			if combatant.would_ai_spend_orbs(chosenMove.move.surgeEffect):
				chosenMove.effectType = Move.MoveEffectType.SURGE
			else:
				chosenMove.effectType = Move.MoveEffectType.CHARGE
		elif chosenMove.effectType == Move.MoveEffectType.SURGE:
			# TEST THIS: just in case somehow the surge move got through but it can't be used, use charge instead
			if chosenMove.move.surgeEffect.orbChange * -1 > combatant.orbs:
				chosenMove.effectType = Move.MoveEffectType.CHARGE
		
		var chosenEffect = chosenMove.move.get_effect_of_type(chosenMove.effectType)
		var targetableCombatants: Array[CombatantNode] = get_targetable_combatant_nodes(combatantNodes, chosenEffect.targets)
		if len(targetableCombatants) == 0:
			printerr('BATTLE ERROR NO TARGETABLE COMBATANTS')
			combatant.command = BattleCommand.new(BattleCommand.Type.NONE)
			return
		var targetPositions: Array[String] = []
		if BattleCommand.is_command_multi_target(chosenEffect.targets):
			for targetableCombatant in targetableCombatants:
				targetPositions.append(targetableCombatant.battlePosition)
		else:
			targetPositions = [ai_pick_single_target(chosenEffect, targetableCombatants)]
		var orbChange: int = combatant.get_orbs_change_choice(chosenEffect)
		combatant.command = BattleCommand.new(BattleCommand.Type.MOVE, chosenMove.move, chosenMove.effectType, orbChange, null, targetPositions)
	elif not is_alive():
		combatant.command = null

func ai_pick_move(combatantNodes: Array[CombatantNode]) -> ChosenMove:
	var pickedMove: ChosenMove = ChosenMove.new()
	var currentStats: Stats = combatant.statChanges.apply(combatant.stats)
	var randomValue: float = randf()
	tmpAllCombatantNodes = combatantNodes
	var moveCandidates: Array[Move] = combatant.stats.moves.filter(ai_filter_move_candidates)
	if len(moveCandidates) == 0: # if no moves fit the stricter criteria
		moveCandidates = combatant.stats.moves.filter(filter_out_unusable) # just don't use a strictly unusable move
	tmpAllCombatantNodes = []
	
	if combatant.aiType == Combatant.AiType.DEBUFFER and randomValue > combatant.aiOverrideWeight:
		# first, check if any opponent has no status and there's a move that can give status
		for combatantNode in combatantNodes:
			if combatantNode.role != role and combatantNode.is_alive():
				var opponentHasStatus: bool = combatantNode.combatant.statusEffect != null
				for move in moveCandidates:
					var effectTypeWithStatus: Move.MoveEffectType = move.effects_with_status()
					var effectTypes: Array[Move.MoveEffectType] = [] 
					if effectTypeWithStatus == Move.MoveEffectType.BOTH:
						effectTypes.append(Move.MoveEffectType.CHARGE)
						effectTypeWithStatus = Move.MoveEffectType.SURGE # append both
					if effectTypeWithStatus != Move.MoveEffectType.NONE:
						effectTypes.append(effectTypeWithStatus)
					for effectType in effectTypes:
						var moveEffect: MoveEffect = move.get_effect_of_type(effectType)
						if not opponentHasStatus and effectType != Move.MoveEffectType.NONE and BattleCommand.is_command_enemy_targeting(moveEffect.targets):
							if effectType != Move.MoveEffectType.SURGE or combatant.would_ai_spend_orbs(moveEffect):
								pickedMove.move = move
								pickedMove.effectType = effectType
								break
			if pickedMove.move != null:
				break
		# if no statusing needs to be done, pick a random move that debuffs
		if pickedMove.move == null:
			var moveChoices: Array[int] = []
			var effectTypeChoices: Array[Move.MoveEffectType] = []
			for moveIdx in range(len(moveCandidates)):
				var move: Move = moveCandidates[moveIdx]
				var moveEffects: Array[MoveEffect] = [move.chargeEffect, move.surgeEffect]
				var moveEffectTypes: Array[Move.MoveEffectType] = [Move.MoveEffectType.CHARGE, Move.MoveEffectType.SURGE]
				for moveEffIdx in range(len(moveEffects)):
					var moveEffect: MoveEffect = moveEffects[moveEffIdx]
					if BattleCommand.is_command_enemy_targeting(moveEffect.targets) and moveEffect.role == MoveEffect.Role.DEBUFF:
						moveChoices.append(moveEffect)
						effectTypeChoices.append(moveEffectTypes[moveEffIdx])
			if len(moveChoices) > 0: # 65% of the time pick a debuff
				var randIdx = randi_range(0, len(moveChoices) - 1)
				pickedMove.move = moveCandidates[moveChoices[randIdx]]
				pickedMove.effectType = effectTypeChoices[randIdx]
	
	if combatant.aiType == Combatant.AiType.BUFFER and randomValue > combatant.aiOverrideWeight:
		# if random chance > override, pick a buff
		var moveChoices: Array[int] = []
		var effectTypeChoices: Array[Move.MoveEffectType] = []
		for moveIdx in range(len(moveCandidates)):
			var move: Move = moveCandidates[moveIdx]
			var moveEffects: Array[MoveEffect] = [move.chargeEffect, move.surgeEffect]
			var moveEffectTypes: Array[Move.MoveEffectType] = [Move.MoveEffectType.CHARGE, Move.MoveEffectType.SURGE]
			for moveEffIdx in range(len(moveEffects)):
				var moveEffect: MoveEffect = moveEffects[moveEffIdx]
				var effectType: Move.MoveEffectType = moveEffectTypes[moveEffIdx]
				for combatantNode in get_targetable_combatant_nodes(combatantNodes, moveEffect.targets):
					if combatantNode.role == role and combatantNode.is_alive():
						var allyHasStatus: bool = combatantNode.combatant.statusEffect != null
						if not allyHasStatus and effectType != Move.MoveEffectType.NONE and \
								not BattleCommand.is_command_enemy_targeting(moveEffect.targets) and \
								moveEffect.role == MoveEffect.Role.BUFF:
							if effectType != Move.MoveEffectType.SURGE or combatant.would_ai_spend_orbs(moveEffect):
								moveChoices.append(moveIdx)
								effectTypeChoices.append(effectType)
		
		if len(moveChoices) > 0:
			var randIdx = randi_range(0, len(moveChoices) - 1)
			pickedMove.move = moveCandidates[moveChoices[randIdx]]
			pickedMove.effectType = effectTypeChoices[randIdx]
			
	if combatant.aiType == Combatant.AiType.SUPPORT and randomValue > combatant.aiOverrideWeight:
		# if random chance > override, pick a support/heal move
		# first, check if any allies need healing
		for combatantNode in combatantNodes:
			if combatantNode.role == role and combatantNode.is_alive():
				var needsHealing: bool = combatantNode.combatant.currentHp < roundi(combatantNode.combatant.stats.maxHp / 2.0)
				for move in moveCandidates:
					var effectType: Move.MoveEffectType = move.effects_with_role(MoveEffect.Role.HEAL)
					if needsHealing and effectType != Move.MoveEffectType.NONE:
						if effectType != Move.MoveEffectType.SURGE or combatant.would_ai_spend_orbs(move.get_effect_of_type(effectType)):
							pickedMove.move = move
							pickedMove.effectType = effectType
							break
			if pickedMove.move != null:
				break
		# otherwise, pick a random support (role == Other) move
		var moveChoices: Array[int] = []
		var effectTypeChoices: Array[Move.MoveEffectType] = []
		for moveIdx in range(len(moveCandidates)):
			var move: Move = moveCandidates[moveIdx]
			var effectType: Move.MoveEffectType = move.effects_with_role(MoveEffect.Role.OTHER)
			if effectType != Move.MoveEffectType.NONE:
				if effectType != Move.MoveEffectType.SURGE or combatant.would_ai_spend_orbs(move.get_effect_of_type(effectType)):
					moveChoices.append(moveIdx)
					moveChoices.append(effectType)
		if len(moveChoices) > 0:
			var randIdx = randi_range(0, len(moveChoices) - 1)
			pickedMove.move = moveCandidates[moveChoices[randIdx]]
			pickedMove.effectType = effectTypeChoices[randIdx]
	
	if combatant.aiType == Combatant.AiType.DAMAGE or pickedMove.move == null: # pick the absolute strongest move
		if combatant.aiType == Combatant.AiType.DAMAGE and randomValue > combatant.aiOverrideWeight:
			var randomChoices: Array[ChosenMove] = []
			for move in moveCandidates:
				var moveEffects: Array[MoveEffect] = [move.chargeEffect, move.surgeEffect]
				var effectTypes: Array[Move.MoveEffectType] = [Move.MoveEffectType.CHARGE, Move.MoveEffectType.SURGE]
				for effectIdx in range(len(moveEffects)):
					var moveEffect: MoveEffect = moveEffects[effectIdx]
					if combatant.could_combatant_surge(moveEffect) and len(get_targetable_combatant_nodes(combatantNodes, moveEffect.targets)) > 0:
						randomChoices.append(ChosenMove.new(move, effectTypes[effectIdx]))
			pickedMove = randomChoices.pick_random()
		else:
			var approxMaxDmg: float = 0
			for move in moveCandidates: # for each move
				var effectTypes: Array[Move.MoveEffectType] = [Move.MoveEffectType.CHARGE, Move.MoveEffectType.SURGE]
				var effects: Array[MoveEffect] = [move.chargeEffect, move.surgeEffect]
				for effectIdx in range(len(effects)):
					var effect = effects[effectIdx]
					var effectType = effectTypes[effectIdx]
					var approxDmg: float = currentStats.get_stat_for_dmg_category(move.category) * effect.power
					if BattleCommand.is_command_multi_target(effect.targets): # if multi-targeting
						approxDmg *= len(get_targetable_combatant_nodes(combatantNodes, effect.targets)) # take into account the amount of targetable combatants
					if pickedMove.move == null or \
							(approxMaxDmg < approxDmg and BattleCommand.is_command_enemy_targeting(effect.targets)): # if this move is approx. stronger
						if effectType != Move.MoveEffectType.SURGE or combatant.would_ai_spend_orbs(move.get_effect_of_type(effectType)):
							pickedMove.move = move # pick it instead
							pickedMove.effectType = effectType
							approxMaxDmg = approxDmg
	
	if pickedMove.move == null or pickedMove.effectType == Move.MoveEffectType.NONE:
		printerr('MAJOR ERROR: ai did not find a move to use ', combatant.save_name(), ': ', battlePosition)
	
	return pickedMove

func filter_out_unusable(a) -> bool:
	if a == null:
		return false
	
	var hasAllies: bool = false
	for combatantNode in tmpAllCombatantNodes:
		if combatantNode.role == role and combatantNode.is_alive() and combatantNode != self:
			hasAllies = true
			break
	
	var numCanUse: int = 2
	for effect in [a.chargeEffect, a.surgeEffect]:
		if (not hasAllies and effect.targets == BattleCommand.Targets.NON_SELF_ALLY) or \
				not combatant.could_combatant_surge(effect):
			numCanUse -= 1 # move cannot be used by the game rules
	return numCanUse > 0 # move could be used

func ai_filter_move_candidates(a: Move) -> bool:
	if not filter_out_unusable(a):
		return false
	var hasAllies: bool = false
	for combatantNode in tmpAllCombatantNodes:
		if combatantNode.role == role and combatantNode.is_alive() and combatantNode != self:
			hasAllies = true
			break
	var moveEffectType: Move.MoveEffectType = a.effects_with_status()
	if moveEffectType != Move.MoveEffectType.NONE: # if move has a status
		var moveEffects: Array[MoveEffect] = []
		if moveEffectType == Move.MoveEffectType.BOTH:
			moveEffectType = Move.MoveEffectType.SURGE
			moveEffects.append(a.get_effect_of_type(Move.MoveEffectType.CHARGE))
		moveEffects.append(a.get_effect_of_type(moveEffectType))
		var statusCanLand: bool = false
		for effect: MoveEffect in moveEffects:
			var enemyTargeting: bool = BattleCommand.is_command_enemy_targeting(effect.targets)
			if (not hasAllies and effect.targets == BattleCommand.Targets.NON_SELF_ALLY) or \
					not combatant.could_combatant_surge(effect):
				# if this move is other-ally only and we don't have a valid target: don't consider it
				# or if the combatant can't pay for this version, don't consider it
				continue 
			if effect.power == 0 or (effect.power > 0 and not enemyTargeting) or (effect.power < 0 and enemyTargeting): # if move effect is purely status or deals damage to an ally to apply status/heals an enemy to apply status:
				for combatantNode in get_targetable_combatant_nodes(tmpAllCombatantNodes, effect.targets):
					if combatantNode.combatant.statusEffect == null:
						statusCanLand = true # if the combatant can be statused, it can be affected
						break
			else:
				# if the move has a secondary status-effect but primarily does heal/damage, consider it regardless
				statusCanLand = true
				break
		return statusCanLand
	return true

func ai_pick_single_target(effect: MoveEffect, targetableCombatants: Array[CombatantNode]) -> String:
	var pickedTarget: String = ''
	var randValue: float = randf()
	if (effect.role == MoveEffect.Role.SINGLE_TARGET_DAMAGE or effect.role == MoveEffect.Role.HEAL) and randValue > combatant.aiOverrideWeight:
		var minHealth: int = -1
		for combatantNode in targetableCombatants:
			if minHealth == -1 or minHealth > combatantNode.combatant.currentHp:
				minHealth = combatantNode.combatant.currentHp
				pickedTarget = combatantNode.battlePosition
	
	if effect.role == MoveEffect.Role.BUFF or effect.role == MoveEffect.Role.DEBUFF:
		var maxHealth: int = 0
		for combatantNode in targetableCombatants:
			if maxHealth < combatantNode.combatant.currentHp:
				maxHealth = combatantNode.combatant.currentHp
				pickedTarget = combatantNode.battlePosition
	
	if pickedTarget == '':
		pickedTarget = targetableCombatants.pick_random().battlePosition
	return pickedTarget

func is_alive() -> bool:
	if combatant == null:
		return false
	return not combatant.downed

func _fade_out_finished():
	fadeOutTween = null
	visible = false
	modulate = Color(1,1,1,1)

func _on_select_combatant_btn_toggled(button_pressed):
	toggled.emit(button_pressed, self)

func _on_click_combatant_btn_pressed():
	print('show details for ', combatant.save_name())
	details_clicked.emit(self)

func _on_animated_sprite_animation_finished():
	animatedSprite.play('stand')
	# if all move sprites have finished and move tween has completely finished
	if battleController != null and playedMoveSprites == 0 and animateTween == null and spriteContainer.global_position == returnToPos:
		battleController.combatant_finished_animating.emit()
	update_hp_tag()

func _on_animate_tween_target_move_finished():
	if battleController != null:
		battleController.combatant_finished_moving.emit()
	update_hp_tag()

func _combatant_finished_moving():
	if playParticlesQueued != null:
		if playHitQueued == null:
			update_hp_tag()
		make_particles_now(playParticlesQueued, playParticlesTimingDelay)
	playParticlesQueued = null
	if len(playMoveSpritesQueued) > 0:
		for moveSprite in playMoveSpritesQueued:
			play_move_sprite(moveSprite)
	playMoveSpritesQueued = []
	moveSpriteTargets = [] # no longer needed; all move sprites have been played!
	if playHitQueued != null:
		playHitEnabled = true

func _combatants_play_hit():
	if playHitQueued != null and playHitEnabled:
		update_hp_tag()
		make_particles_now(playHitQueued, playHitTimingDelay)
		playHitQueued = null
		playHitEnabled = false

func _combatant_finished_animating():
	_combatants_play_hit()
	if moveSpritesCallback != Callable() and animateTween == null and playedMoveSprites == 0:
		moveSpritesCallback.call()
		moveSpritesCallback = Callable()

func _on_animate_tween_finished():
	animateTween = null
	if playedMoveSprites == 0:
		tween_back_to_return_pos()

func _on_combatant_tween_returned():
	animateTween = null
	if playedMoveSprites == 0:
		battleController.combatant_finished_animating.emit()
		if moveSpritesCallback != Callable():
			moveSpritesCallback.call()
			moveSpritesCallback = Callable()

func _on_hp_drain_tween_finished():
	hpDrainTween = null

func _move_sprite_complete():
	playedMoveSprites -= 1
	# if the combatant's sprite animation is done and all move sprites have finished
	if battleController != null and playedMoveSprites == 0 and animatedSprite.animation == 'stand':
		if animateTween == null:
			if spriteContainer.global_position != returnToPos:
				tween_back_to_return_pos()
			else:
				battleController.combatant_finished_animating.emit()
		
