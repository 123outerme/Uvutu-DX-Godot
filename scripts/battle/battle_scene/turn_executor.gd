extends Node
class_name TurnExecutor

@export var battleController: BattleController
@export var battleUI: BattleUI

var allCombatants: Array[Combatant] = []

var turnQueue: TurnQueue = TurnQueue.new()
var escaping: bool = false
var result: WinCon.TurnResult = WinCon.TurnResult.NOTHING

func start_simulation():
	battleController.state.statusEffDamagedCombatants = []
	var combatants: Array[Combatant] = []
	var allCombatantNodes: Array[CombatantNode] = battleController.get_all_combatant_nodes()
	for combatantNode in allCombatantNodes:
		if combatantNode.is_alive():
			allCombatants.append(combatantNode.combatant)
	
	for combatantNode in allCombatantNodes:
		if combatantNode.is_alive():
			if combatantNode.role == CombatantNode.Role.ENEMY:
				combatantNode.get_command(allCombatantNodes)
			combatants.append(combatantNode.combatant)
			combatantNode.combatant.command.get_targets_from_combatant_nodes(allCombatantNodes)
			# apply before-round effects
			if combatantNode.combatant.statusEffect != null:
				battleController.state.statusEffDamagedCombatants.append_array(
					combatantNode.combatant.statusEffect.apply_status(combatantNode.combatant, allCombatants, BattleCommand.ApplyTiming.BEFORE_ROUND)
				)
			if combatantNode.combatant.stats.equippedWeapon != null:
				combatantNode.combatant.stats.equippedWeapon.apply_effects(combatantNode.combatant, BattleCommand.ApplyTiming.BEFORE_ROUND)
			if combatantNode.combatant.stats.equippedArmor != null:
				combatantNode.combatant.stats.equippedArmor.apply_effects(combatantNode.combatant, BattleCommand.ApplyTiming.BEFORE_ROUND)
	turnQueue = TurnQueue.new(combatants)

func play_turn():
	var allCombatantNodes: Array[CombatantNode] = battleController.get_all_combatant_nodes()
	var combatant: Combatant = turnQueue.peek_next()
	if combatant != null: # apply before-damage-calc status
		battleController.state.statusEffDamagedCombatants = []
		combatant.command.get_targets_from_combatant_nodes(allCombatantNodes) # make sure to get all commands before applying statuses
		# apply status effect effects Before Dmg Calc
		if combatant.statusEffect != null:
			battleController.state.statusEffDamagedCombatants.append_array(
				combatant.statusEffect.apply_status(combatant, allCombatants, BattleCommand.ApplyTiming.BEFORE_DMG_CALC)
			)
		# apply equipment boosts Before Dmg Calc
		#if combatant.stats.equippedArmor != null:
		#	combatant.stats.equippedArmor.apply_effects(combatant, BattleCommand.ApplyTiming.BEFORE_DMG_CALC)
		#if combatant.stats.equippedWeapon != null:
		#	combatant.stats.equippedWeapon.apply_effects(combatant, BattleCommand.ApplyTiming.BEFORE_DMG_CALC)
		# Execute the command: attack, use item, attempt to flee, etc.
		escaping = combatant.command.execute_command(combatant, allCombatantNodes) # perform all necessary calculations
		# apply after-damage-calc status
		if combatant.statusEffect != null:
			battleController.state.statusEffDamagedCombatants.append_array(
				combatant.statusEffect.apply_status(combatant, allCombatants, BattleCommand.ApplyTiming.AFTER_DMG_CALC)
			)
		# apply equipment boosts After Dmg Calc
		#if combatant.stats.equippedArmor != null:
		#	combatant.stats.equippedArmor.apply_effects(combatant, BattleCommand.ApplyTiming.AFTER_DMG_CALC)
		#if combatant.stats.equippedWeapon != null:
		#	combatant.stats.equippedWeapon.apply_effects(combatant, BattleCommand.ApplyTiming.AFTER_DMG_CALC)
		for defender in combatant.command.targets:
			if defender.statusEffect != null: # apply "specifically afer taking damage" statuses
				battleController.state.statusEffDamagedCombatants.append_array(
					defender.statusEffect.apply_status(defender, allCombatants, BattleCommand.ApplyTiming.AFTER_RECIEVING_DMG)
				)
			# if a move was used: get the move effect
			if combatant.command.type == BattleCommand.Type.MOVE and combatant.command.move != null:
				var moveEffect: MoveEffect = combatant.command.move.get_effect_of_type(combatant.command.moveEffectType)
				if combatant.command.moveEffectType == Move.MoveEffectType.SURGE: # apply surge effects
					moveEffect = moveEffect.apply_surge_changes(combatant.command.orbChange * -1)
				# if the move dealt direct (non-redirected) damage to the defender, then apply After Recieving Damage timing equipment effects
				if moveEffect.power > 0:
					if defender.stats.equippedArmor != null:
						defender.stats.equippedArmor.apply_effects(defender, BattleCommand.ApplyTiming.AFTER_RECIEVING_DMG)
					if defender.stats.equippedWeapon != null:
						defender.stats.equippedWeapon.apply_effects(defender, BattleCommand.ApplyTiming.AFTER_RECIEVING_DMG)
				
		update_turn_text()
	else:
		battleController.state.statusEffDamagedCombatants = []
		for combatantNode in battleController.get_all_combatant_nodes(): # apply after-round effects
			if combatantNode.is_alive():
				if combatantNode.combatant.statusEffect != null:
					battleController.state.statusEffDamagedCombatants.append_array(
						combatantNode.combatant.statusEffect.apply_status(combatantNode.combatant, allCombatants, BattleCommand.ApplyTiming.AFTER_ROUND)
					)
				if combatantNode.combatant.stats.equippedWeapon != null:
					combatantNode.combatant.stats.equippedWeapon.apply_effects(combatantNode.combatant, BattleCommand.ApplyTiming.AFTER_ROUND)
				if combatantNode.combatant.stats.equippedArmor != null:
					combatantNode.combatant.stats.equippedArmor.apply_effects(combatantNode.combatant, BattleCommand.ApplyTiming.AFTER_ROUND)
		battleUI.set_menu_state(BattleState.Menu.POST_ROUND)
	
func update_turn_text() -> bool:
	var allCombatantNodes: Array[CombatantNode] = battleController.get_all_combatant_nodes()
	var text: String = ''
	
	''' enabling ability to set breakpoint for debugging status dmg particles
	if len(battleController.state.statusEffDamagedCombatants) > 0:
		print('status dmgd combatants')
	#'''
	
	if battleUI.menuState == BattleState.Menu.PRE_BATTLE or battleUI.menuState == BattleState.Menu.PRE_ROUND or battleUI.menuState == BattleState.Menu.POST_ROUND:
		if len(battleController.state.calcdStateStrings) == 0:
			calculate_intermediate_state_strings(allCombatantNodes)
			if len(battleController.state.calcdStateStrings) == 0:
				battleUI.advance_intermediate_state(result)
				return false
			else:
				text = battleController.state.calcdStateStrings[0]
		elif battleController.state.calcdStateIndex < len(battleController.state.calcdStateStrings):
			text = battleController.state.calcdStateStrings[battleController.state.calcdStateIndex]
		
		if battleController.state.calcdStateIndex < len(battleController.state.calcdStateStrings) and \
				battleController.state.calcdStateCombatants[battleController.state.calcdStateIndex] in battleController.state.statusEffDamagedCombatants:
			for cNode: CombatantNode in allCombatantNodes:
				if cNode.combatant == battleController.state.calcdStateCombatants[battleController.state.calcdStateIndex]:
					cNode.play_particles(BattleCommand.get_hit_particles(), false)
					cNode.update_hp_tag()
					break
	
	if battleUI.menuState == BattleState.Menu.RESULTS:
		var combatant: Combatant = turnQueue.peek_next()
		var defenders: Array[Combatant] = []
		if combatant != null:
			combatant.command.get_targets_from_combatant_nodes(allCombatantNodes)
			text = combatant.command.get_command_results(combatant)
			defenders.append_array(combatant.command.targets)
			for interceptor in combatant.command.interceptingTargets:
				if not interceptor in defenders:
					defenders.append(interceptor)
			if combatant.statusEffect != null:
				text += ' ' + combatant.statusEffect.get_status_effect_str(combatant, allCombatants, BattleCommand.ApplyTiming.AFTER_DMG_CALC)
			for defender in defenders:
				if not defender == combatant and defender.statusEffect != null:
					text += ' ' + defender.statusEffect.get_status_effect_str(defender, allCombatants, BattleCommand.ApplyTiming.AFTER_DMG_CALC)
				# if the defender did not intercept the attack (was directed at this defender):
				if defender in combatant.command.targets:
					# if a move was used: get the move effect
					if combatant.command.type == BattleCommand.Type.MOVE and combatant.command.move != null:
						var moveEffect: MoveEffect = combatant.command.move.get_effect_of_type(combatant.command.moveEffectType)
						if combatant.command.moveEffectType == Move.MoveEffectType.SURGE: # apply surge effects
							moveEffect = moveEffect.apply_surge_changes(combatant.command.orbChange * -1)
						# if the move dealt damage to the defender, then show the After Recieving Dmg equipment effects
						if moveEffect.power > 0:
							if defender.stats.equippedWeapon != null:
								var afterDmgText: String = defender.stats.equippedWeapon.get_apply_text(defender, BattleCommand.ApplyTiming.AFTER_RECIEVING_DMG)
								if afterDmgText != '':
									text += ' ' + afterDmgText
							if defender.stats.equippedArmor != null:
								var afterDmgText: String = defender.stats.equippedArmor.get_apply_text(defender, BattleCommand.ApplyTiming.AFTER_RECIEVING_DMG)
								if afterDmgText != '':
									text += ' ' + afterDmgText

		var userNode: CombatantNode = null
		var defenderNodes: Array[CombatantNode] = []
		var targetNodes: Array[CombatantNode] = []
		for combatantNode: CombatantNode in allCombatantNodes:
			if combatantNode.combatant == combatant:
				combatantNode.play_animation(combatant.command.get_command_animation())
				userNode = combatantNode
			if combatantNode.combatant in defenders:
				defenderNodes.append(combatantNode)
				if combatant.command.type == BattleCommand.Type.USE_ITEM:
					combatantNode.update_hp_tag()
			if combatantNode.combatant in combatant.command.targets:
				targetNodes.append(combatantNode)
				var resultIdx: int = combatant.command.targets.find(combatantNode.combatant)
				if combatant.command.commandResult != null and resultIdx > -1 and resultIdx < len(combatant.command.commandResult.afflictedStatuses):
					combatantNode.isBeingStatusAfflicted = true
		
		userNode.moveSpriteTargets = targetNodes
		var commandMoveSprites: Array[MoveAnimSprite] = combatant.command.get_command_sprites()
		if combatant.command.type == BattleCommand.Type.USE_ITEM:
			userNode.useItemSprite = combatant.command.slot.item.itemSprite
		userNode.play_move_sprites(commandMoveSprites)
		if len(commandMoveSprites) > 0:
			battleUI.results.tween_started() # signal to the UI not to let the player continue until the animation is over
			userNode.move_animation_callback(battleUI.results._move_tween_finished)
			
		if userNode != null and combatant.command.commandResult != null:
			var moveEffect: MoveEffect = null
			if combatant.command.move != null:
				moveEffect = combatant.command.move.get_effect_of_type(combatant.command.moveEffectType)
			var moveToPos = userNode.global_position # fallback: self (no movement)
			var multiIsAllies: bool = false
			var multiIsEnemies: bool = false
			if combatant.command.moveEffectType == Move.MoveEffectType.SURGE:
				var surgeParticles: ParticlePreset = preload("res://gamedata/moves/particles_surge.tres")
				userNode.play_particles(surgeParticles)
			for combatantNode in allCombatantNodes:
				if combatantNode.is_alive() and (combatantNode.combatant in defenders or combatantNode.combatant == userNode.combatant):
					var particlePresets: Array[ParticlePreset] = combatant.command.get_particles(combatantNode, userNode, combatantNode.combatant in defenders)
					
					# play recoil dmg effect
					if combatantNode.combatant in battleController.state.statusEffDamagedCombatants:
						combatantNode.play_particles(BattleCommand.get_hit_particles(), true, 0.5)
					for preset in particlePresets:
						combatantNode.play_particles(preset, combatantNode != userNode)
					# if there's only one target:
					if len(combatant.command.targets) == 1:
						# if this combatant is the target:
						if combatant.command.targets[0] == combatantNode.combatant:
							# if the combatant is an ally:
							if combatantNode.role == userNode.role:
								if combatantNode.combatant == userNode.combatant:
									moveToPos = userNode.global_position # self position
								else:
									moveToPos = combatantNode.onAssistMarker.global_position # ally assist position
							else:
								# the combatant is an enemy
								moveToPos = combatantNode.onAttackMarker.global_position
					elif combatantNode.combatant in defenders:
						# if this combatant is an ally
						if combatantNode.role == userNode.role:
							multiIsAllies = true
						else:
							multiIsEnemies = true # this combatant is an enemy
			
			# if it's a move, fix if a move is multi-targeting but there's only one combatant
			if combatant.command.type == BattleCommand.Type.MOVE:
				if not multiIsAllies:
					multiIsAllies = moveEffect.targets == BattleCommand.Targets.ALL_ALLIES or moveEffect.targets == BattleCommand.Targets.ALL_EXCEPT_SELF or moveEffect.targets == BattleCommand.Targets.ALL
				if not multiIsEnemies:
					multiIsEnemies = moveEffect.targets == BattleCommand.Targets.ALL_ENEMIES or moveEffect.targets == BattleCommand.Targets.ALL_EXCEPT_SELF or moveEffect.targets == BattleCommand.Targets.ALL
			
			# if targeting multiple:
			if multiIsAllies or multiIsEnemies:
				# if targeting both allies and enemies
				if multiIsAllies and multiIsEnemies:
					moveToPos = battleController.globalMarker.global_position # use global move pos
				elif multiIsAllies:
					moveToPos = userNode.allyTeamMarker.global_position # use ally team pos
				else:
					moveToPos = userNode.enemyTeamMarker.global_position # use enemy team pos
			
			if not ( \
					(combatant.command.type == BattleCommand.Type.MOVE and not combatant.command.move.moveAnimation.makesContact) \
					or combatant.command.type == BattleCommand.Type.ESCAPE) and moveToPos != userNode.global_position:
				# if it's a non-contact move, an escape, or the user would move to self, do no move tweening, otherwise do tweening
				battleUI.results.tween_started() # signal to the UI not to let the player continue until the animation is over
				userNode.tween_to(moveToPos) # tween
				userNode.move_animation_callback(battleUI.results._move_tween_finished)
			else:
				userNode.move_animation_callback(battleUI.results._move_tween_finished)
				battleController.combatant_finished_moving.emit() # no tween was started so finish instantly
			
		
	battleUI.results.show_text(text)
	return text != ''

func finish_turn() -> WinCon.TurnResult:
	var lastCombatant: Combatant = turnQueue.pop() # remove the turn from the queue
	lastCombatant.command = null # remove the command from the previous turn's combatant
	result = check_battle_end_conditions()
	if result == WinCon.TurnResult.NOTHING:
		play_turn() # go to the next turn
	return result

func check_battle_end_conditions() -> WinCon.TurnResult:
	for combatantNode in battleController.get_all_combatant_nodes():
		if combatantNode.combatant != null:
			combatantNode.combatant.update_downed()
		if not combatantNode.is_alive(): # if combatant is not alive (after being updated)
			combatantNode.update_hp_tag() # then the combatant should be shown as defeated
	var turnResult: WinCon.TurnResult = PlayerResources.playerInfo.encounter.get_win_con_result(battleController.get_all_combatant_nodes(), battleController.state)
	if turnResult != WinCon.TurnResult.NOTHING:
		return turnResult
	if escaping: # if escaping
		turnQueue.empty() # end the round immediately
		return WinCon.TurnResult.ESCAPE
	return WinCon.TurnResult.NOTHING

func calculate_intermediate_state_strings(allCombatantNodes: Array[CombatantNode]):
	battleController.state.calcdStateStrings = []
	battleController.state.calcdStateCombatants = []
	for combatantNode in allCombatantNodes:
		# instead of combatantNode.is_alive(), check if visible and combatant is not null
		if combatantNode.combatant != null and combatantNode.visible:
			if battleUI.menuState == BattleState.Menu.PRE_BATTLE:
				var equippedWeaponText: String = ''
				var equippedArmorText: String = ''
				if combatantNode.combatant.stats.equippedWeapon != null:
					equippedWeaponText = combatantNode.combatant.stats.equippedWeapon.get_apply_text(combatantNode.combatant, BattleCommand.ApplyTiming.BEFORE_BATTLE)
				if combatantNode.combatant.stats.equippedArmor != null:
					equippedArmorText = combatantNode.combatant.stats.equippedArmor.get_apply_text(combatantNode.combatant, BattleCommand.ApplyTiming.BEFORE_BATTLE)
				if equippedWeaponText != '' or equippedArmorText != '':
					if equippedWeaponText != '' and equippedArmorText != '':
						equippedWeaponText += ' '
					battleController.state.calcdStateStrings.append(equippedWeaponText + equippedArmorText)
					battleController.state.calcdStateCombatants.append(combatantNode.combatant)
			
			if battleUI.menuState == BattleState.Menu.PRE_ROUND or battleUI.menuState == BattleState.Menu.POST_ROUND:
				var timing: BattleCommand.ApplyTiming = BattleCommand.ApplyTiming.BEFORE_ROUND if battleUI.menuState == BattleState.Menu.PRE_ROUND else BattleCommand.ApplyTiming.AFTER_ROUND
				var statusEffectString: String = ''
				if combatantNode.combatant.statusEffect != null:
					statusEffectString = combatantNode.combatant.statusEffect.get_status_effect_str(combatantNode.combatant, allCombatants, timing)
				
				var equippedWeaponText: String = ''
				var equippedArmorText: String = ''
				
				if combatantNode.combatant.stats.equippedWeapon != null:
					equippedWeaponText = combatantNode.combatant.stats.equippedWeapon.get_apply_text(combatantNode.combatant, timing)
				if combatantNode.combatant.stats.equippedArmor != null:
					equippedArmorText = combatantNode.combatant.stats.equippedArmor.get_apply_text(combatantNode.combatant, timing)
				if equippedWeaponText != '' or equippedArmorText != '':
					if equippedWeaponText != '' and equippedArmorText != '':
						equippedWeaponText += ' '
					if statusEffectString != '':
						statusEffectString += ' '
					statusEffectString += equippedWeaponText + equippedArmorText
				if statusEffectString != '':
					battleController.state.calcdStateStrings.append(statusEffectString)
					battleController.state.calcdStateCombatants.append(combatantNode.combatant)

func advance_precalcd_text() -> bool:
	battleController.state.calcdStateIndex += 1
	update_turn_text()
	return battleController.state.calcdStateIndex >= len(battleController.state.calcdStateStrings)

func find_combatant_node_by_combatant(cNodes: Array[CombatantNode], c: Combatant) -> CombatantNode:
	for node in cNodes:
		if node.combatant == c:
			return node
	return null
