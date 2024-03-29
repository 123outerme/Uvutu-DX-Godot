extends Resource
class_name Combatant

enum AiType {
	NONE = 0,
	DAMAGE = 1,
	SUPPORT = 2,
	BUFFER = 3,
	DEBUFFER = 4,
}

enum ResourceStrategy {
	GREEDY = 0,
	BIG_SPENDER = 1,
	BIG_SAVER = 2,
}

const HP_BAR_COLORS: Dictionary = {
	'full': Color(0, 1, 0), #00ff00
	'warn': Color(1, 0.71764707565308, 0), #ffb700
	'low': Color(1, 0.3137255012989, 0) # ff5000
}

const MAX_ORBS = 10

@export_category("Combatant - Sprite")
@export var spriteFrames: SpriteFrames = null
@export var maxSize: Vector2 = Vector2(16, 16)
@export var spriteFacesRight: bool = false
@export_flags_2d_navigation var navigationLayer: int = 1

@export_category("Combatant - Stats")
@export var nickname: String = ''
@export var stats: Stats = Stats.new()
@export var currentHp: int = -1
@export var orbs: int = 0
@export var statChanges: StatChanges = StatChanges.new()
@export var statusEffect: StatusEffect = null
@export var friendship: float = 0
@export var maxFriendship: float = 30

@export_category("Combatant - Encounter")
@export var aiType: AiType = AiType.NONE
@export var strategy: ResourceStrategy = ResourceStrategy.GREEDY
@export var aiOverrideWeight: float = 0.35
@export var equipmentTable: Array[WeightedEquipment] = []
@export var teamTable: Array[WeightedString] = []
# NOTE: having a weighted combatant caused recursion errors, so this is the workaround
@export var dropTable: Array[WeightedReward] = []
@export var innateStatCategories: Array[Stats.Category] = []

@export_category("Combatant - In Battle")
@export var command: BattleCommand = null
@export var downed: bool = false

static var useSurgeReqs: StoryRequirements = load('res://gamedata/story_requirements/surge_move_reqs.tres')

static func load_combatant_resource(saveName: String) -> Combatant:
	var combatant: Combatant = load("res://gamedata/combatants/" + saveName + '/' + saveName + ".tres").copy()
	if combatant.currentHp == -1:
		combatant.currentHp = combatant.stats.maxHp # load max HP if combatant was loaded from resource
	return combatant

static func get_hp_bar_color(curHp: float, maxHp: float) -> Color:
	var hpRatio = curHp / maxHp
	if hpRatio >= 0.65:
		return HP_BAR_COLORS.full
	if hpRatio >= 0.35:
		return HP_BAR_COLORS.warn
	return HP_BAR_COLORS.low

func _init(
	i_nickname = '',
	i_stats = Stats.new(),
	i_curHp = -1,
	i_statChanges = StatChanges.new(),
	i_statusEffect = null,
	i_sprite = null,
	i_maxSize = Vector2(16, 16),
	i_facesRight = false,
	i_navLayer = 1,
	i_friendship = 0,
	i_aiType = AiType.NONE,
	i_overrideWeight = 0.35,
	i_equipmentTable: Array[WeightedEquipment] = [],
	i_teamTable: Array[WeightedString] = [],
	i_dropTable: Array[WeightedReward] = [],
	i_innateStats: Array[Stats.Category] = [],
	i_command = null,
	i_downed = false,
):
	nickname = i_nickname
	stats = i_stats
	if i_curHp != -1:
		currentHp = i_curHp
	else:
		currentHp = stats.maxHp
	statChanges = i_statChanges
	statusEffect = i_statusEffect
	spriteFrames = i_sprite
	spriteFacesRight = i_facesRight
	maxSize = i_maxSize
	navigationLayer = i_navLayer
	aiType = i_aiType
	friendship = i_friendship
	aiOverrideWeight = i_overrideWeight
	equipmentTable = i_equipmentTable
	teamTable = i_teamTable
	dropTable = i_dropTable
	innateStatCategories = i_innateStats
	command = i_command
	downed = i_downed

func disp_name() -> String:
	if nickname != '':
		return nickname
	return stats.displayName

func save_name() -> String:
	return stats.saveName

func update_downed():
	downed = currentHp <= 0

func get_exhaustion_level() -> StatusEffect.Potency:
	if statusEffect == null or statusEffect.type != StatusEffect.Type.EXHAUSTION:
		return StatusEffect.Potency.NONE # if no status or not exhaustion
	return statusEffect.potency # return exhaustion potency
	
func get_mania_level() -> StatusEffect.Potency:
	if statusEffect == null or statusEffect.type != StatusEffect.Type.MANIA:
		return StatusEffect.Potency.NONE # if no status or not exhaustion
	return statusEffect.potency # return manic potency

func would_item_have_effect(item: Item) -> bool:
	if item.itemType == Item.Type.HEALING:
		return currentHp < stats.maxHp
	return true

func add_orbs(num: int):
	orbs = max(0, min(Combatant.MAX_ORBS, orbs + num)) # bounded [0,max]

func get_starting_orbs() -> int:
	var bonusOrbs: int = 0
	if stats.equippedWeapon != null:
		bonusOrbs += stats.equippedWeapon.bonusOrbs
	if stats.equippedArmor != null:
		bonusOrbs += stats.equippedArmor.bonusOrbs
	
	return max(0, min(Combatant.MAX_ORBS, bonusOrbs)) # bounded [0, max]

func could_combatant_surge(effect: MoveEffect) -> bool:
	if effect.orbChange >= 0:
		return true # no cost required to charge orbs
	
	if Combatant.useSurgeReqs != null and not Combatant.useSurgeReqs.is_valid():
		return false # AI can't use surge moves yet
	return true

func would_ai_spend_orbs(effect: MoveEffect) -> bool:
	if not could_combatant_surge(effect):
		return false
	
	var spendingOrbs: int = effect.orbChange * -1
	
	match strategy:
		ResourceStrategy.GREEDY:
			return orbs >= spendingOrbs # if we have the orbs, do it
		ResourceStrategy.BIG_SPENDER:
			return orbs >= spendingOrbs + 2 or orbs == 10 # if we have 2 more orbs than required, or we have 10 orbs, then do it
		ResourceStrategy.BIG_SAVER:
			return orbs >= spendingOrbs + 2 or orbs == 10 # if we have 2 more orbs than required, or we have 10 orbs, then do it
	return false # default: never spend orbs

func get_orbs_change_choice(moveEffect: MoveEffect) -> int:
	if moveEffect.orbChange >= 0:
		return moveEffect.orbChange # if we don't have the choice to spend, just return the number
	else:
		# spending orbs:
		match strategy:
			ResourceStrategy.GREEDY:
				return orbs * -1 # always spend max
			ResourceStrategy.BIG_SPENDER:
				return orbs * -1 # always spend max
			ResourceStrategy.BIG_SAVER:
				if currentHp <= 0.25 * stats.maxHp:
					return orbs * -1 # spend max if health is <= 25%; could be gone next turn!
				var spending: int = moveEffect.orbChange # start with minimum
				# if combatant can upgrade status to at least weak, do it
				if moveEffect.surgeChanges.weakThresholdOrbs > abs(moveEffect.orbChange) and orbs > moveEffect.surgeChanges.weakThresholdOrbs:
					spending = moveEffect.surgeChanges.weakThresholdOrbs * -1
				# if combatant can upgrade status to at least strong, do it
				if moveEffect.surgeChanges.strongThresholdOrbs > abs(moveEffect.orbChange) and orbs > moveEffect.surgeChanges.strongThresholdOrbs:
					spending = moveEffect.surgeChanges.strongThresholdOrbs * -1
				# if combatant can upgrade status to overwhelming, do it
				if moveEffect.surgeChanges.overwhelmingThresholdOrbs > abs(moveEffect.orbChange) and orbs > moveEffect.surgeChanges.overwhelmingThresholdOrbs:
					spending = moveEffect.surgeChanges.overwhelmingThresholdOrbs * -1
				return spending
		return moveEffect.orbChange # default: always spend minimum

func level_up_nonplayer(newLv: int):
	var lvDiff: int = newLv - stats.level
	if lvDiff > 0:
		stats.level_up(lvDiff)
		currentHp = stats.maxHp
		# if there are innate stat categories to allocate to
		if len(innateStatCategories) > 0:
			while stats.statPts > 0:
				# randomly allocate stats to the innate stat categories
				var randomCategory: Stats.Category = innateStatCategories.pick_random()
				if randomCategory == Stats.Category.PHYS_ATK:
					stats.physAttack += 1
				if randomCategory == Stats.Category.MAGIC_ATK:
					stats.magicAttack += 1
				if randomCategory == Stats.Category.RESISTANCE or randomCategory == Stats.Category.HP: # HP shouldn't be picked, but in case, just increase resistance
					stats.resistance += 1
				if randomCategory == Stats.Category.AFFINITY:
					stats.affinity += 1
				if randomCategory == Stats.Category.SPEED:
					stats.speed += 1
				stats.statPts -= 1
	elif lvDiff < 0:
		printerr("level up nonplayer err: level diff is negative")

func assign_moves_nonplayer():
	var nextMoveSlot: int = 0
	stats.moves = []
	for move: Move in stats.movepool.pool:
		if move.requiredLv <= stats.level:
			stats.moves.insert(nextMoveSlot, move)
			nextMoveSlot = (nextMoveSlot + 1) % 4

func copy() -> Combatant:
	var newCombatant: Combatant = Combatant.new()
	newCombatant.save_from_object(self)
	return newCombatant

func save_from_object(c: Combatant):
	stats = c.stats.copy()
	nickname = c.nickname
	currentHp = c.currentHp
	
	if c.statChanges != null:
		statChanges = c.statChanges.duplicate(true)
	else:
		statChanges = null
		
	if c.statusEffect != null:
		statusEffect = c.statusEffect.duplicate(true)
	else:
		statusEffect = null
	maxSize = c.maxSize
	spriteFrames = c.spriteFrames
	spriteFacesRight = c.spriteFacesRight
	navigationLayer = c.navigationLayer
	aiType = c.aiType
	friendship = c.friendship
	aiOverrideWeight = c.aiOverrideWeight
	equipmentTable = c.equipmentTable.duplicate(false)
	teamTable = c.teamTable.duplicate(false)
	dropTable = c.dropTable.duplicate(false)
	innateStatCategories = c.innateStatCategories.duplicate(false)
	
	if c.command != null:
		command = c.command.duplicate(false)
	else:
		command = null
	
	downed = c.downed
