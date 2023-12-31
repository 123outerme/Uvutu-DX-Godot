extends Resource
class_name Combatant

enum AiType {
	NONE = 0,
	DAMAGE = 1,
	SUPPORT = 2,
	BUFFER = 3,
	DEBUFFER = 4,
}

@export_category("Combatant - Sprite")
@export var spriteFrames: SpriteFrames = null
@export var maxSize: Vector2 = Vector2(16, 16)
@export var spriteFacesRight: bool = false
@export_flags_2d_navigation var navigationLayer: int = 1

@export_category("Combatant - Stats")
@export var nickname: String = ''
@export var stats: Stats = Stats.new()
@export var currentHp: int = -1
@export var statChanges: StatChanges = StatChanges.new()
@export var statusEffect: StatusEffect = null

@export_category("Combatant - Encounter")
@export var aiType: AiType = AiType.NONE
@export var aiOverrideWeight: float = 0.35
@export var equipmentTable: Array[WeightedEquipment] = []
@export var teamTable: Array[WeightedString] = []
# NOTE: having a weighted combatant caused recursion errors, so this is the workaround
@export var dropTable: Array[WeightedReward] = []
@export var innateStatCategories: Array[Stats.Category] = []

@export_category("Combatant - In Battle")
@export var command: BattleCommand = null
@export var downed: bool = false

static func load_combatant_resource(saveName: String) -> Combatant:
	var combatant: Combatant = load("res://gamedata/combatants/" + saveName + ".tres").copy()
	if combatant.currentHp == -1:
		combatant.currentHp = combatant.stats.maxHp # load max HP if combatant was loaded from resource
	return combatant

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
	
func get_manic_level() -> StatusEffect.Potency:
	if statusEffect == null or statusEffect.type != StatusEffect.Type.MANIC:
		return StatusEffect.Potency.NONE # if no status or not exhaustion
	return statusEffect.potency # return manic potency

func level_up_nonplayer(newLv: int):
	var lvDiff: int = newLv - stats.level
	if lvDiff > 0:
		stats.level_up(lvDiff)
		currentHp = stats.maxHp
		# if there are innate stat categories to allocate to
		if len(innateStatCategories) > 0:
			while stats.statPts > 0:
				# randomly allocate stats to the innate stat categories
				var randomCategory: Stats.Category = innateStatCategories[randi_range(0, len(innateStatCategories) - 1)]
				if randomCategory == Stats.Category.PHYS_ATK:
					stats.physAttack += 1
				if randomCategory == Stats.Category.MAGIC_ATK:
					stats.magicAttack += 1
				if randomCategory == Stats.Category.RESISTANCE:
					stats.resistance += 1
				if randomCategory == Stats.Category.AFFINITY:
					stats.affinity += 1
				if randomCategory == Stats.Category.SPEED:
					stats.speed += 1
				stats.statPts -= 1
	elif lvDiff < 0:
		printerr("level up nonplayer err: level diff is negative")

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
