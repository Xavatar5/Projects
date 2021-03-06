extends Node

const SavingModuleGd         = preload("res://core/SavingModule.gd")
const SerializerGd           = preload("res://addons/Serialization/HierarchicalSerializer.gd")
const LevelLoaderGd          = preload("./LevelLoader.gd")
const PlayerAgentGd          = preload("res://core/agent/PlayerAgent.gd")
const UnitCreationDatumGd    = preload("res://core/UnitCreationDatum.gd")
const FogOfWarGd             = preload("res://core/level/FogOfWar.gd")

const PlayerName = "Player1"

var _game : Node
var _levelLoader : LevelLoaderGd       setget deleted


signal createFinished( error )


func deleted(_a):
	assert(false)


func initialize( gameScene : Node ):
	_game = gameScene
	_levelLoader = LevelLoaderGd.new( gameScene )


func createFromModule( module : SavingModuleGd, unitsCreationData : Array ) -> int:
	assert( _game._module == null )
	_game.setCurrentModule( module )

	var result = yield( _create( unitsCreationData ), "completed" )
	emit_signal( "createFinished", result )
	return result


func createFromFile( filePath : String ):
	yield( _clearGame(), "completed" )

	var module : SavingModuleGd = _game._module
	if not module or not module.moduleMatches( filePath ):
		var result = _createNewModule( filePath )
		if result != OK:
			Debug.error( self, "Could not create module from %s" % filePath )
			return result
	else:
		module.loadFromFile( filePath )

	var result = yield( _create( [] ), "completed" )
	if result != OK:
		return result

	SerializerGd.deserialize( _game._module.getPlayerData(), _game._playerManager )
	return result


func unloadCurrentLevel():
	var result = yield( _levelLoader.unloadLevel(), "completed" )


func loadLevel( levelName : String, withState := true ) -> int:
	var levelState = _game._module.loadLevelState( levelName, true ) \
		if withState \
		else null

	yield( _loadLevel( levelName, levelState ), "completed" )
	return OK


func _create( unitsCreationData : Array ) -> int:
	yield( get_tree(), "idle_frame" )

	assert( _game._module )
	assert( get_tree().paused )

	var module : SavingModuleGd = _game._module
	var levelName = module.getCurrentLevelName()
	var levelState = module.loadLevelState( levelName, true )
	var result = yield( _loadLevel( levelName, levelState ), "completed" )

	var entranceName = module.getLevelEntrance( levelName )
	if not entranceName.empty() and not unitsCreationData.empty():
		_createAndInsertUnits( unitsCreationData, entranceName )

	return OK


func _loadLevel( levelName : String, levelState = null ):
	yield( get_tree(), "idle_frame" )

	var filePath = _game._module.getLevelFilename( levelName )
	if filePath.empty():
		return ERR_CANT_CREATE

	var result = yield( _levelLoader.loadLevel(
		filePath, _game._currentLevelParent ), "completed" )

	if result != OK:
		return result

	_game.currentLevel.applyFogToLevel( FogOfWarGd.TileType.Fogged )

	if levelState != null:
		SerializerGd.deserialize( levelState, _game._currentLevelParent )

	return OK


func _createNewModule( filePath : String ) -> int:
	assert( _game._module == null )
	assert( _game.currentLevel == null )

	var module = SavingModuleGd.createFromSaveFile( filePath )
	if not module:
		Debug.error( null, "Could not load game from file %s" % filePath )
		return ERR_CANT_CREATE
	else:
		_game.setCurrentModule( module )
	return OK


func _createAndInsertUnits( playerUnitData : Array, entranceName : String ):
	var playerUnits__ = _createPlayerUnits__( playerUnitData )
	_game._playerManager.setPlayerUnits( playerUnits__ )

	var unitNodes : Array = _game._playerManager.getPlayerUnits()
	_levelLoader.insertPlayerUnits( unitNodes, _game.currentLevel, entranceName )


func _createPlayerUnits__( unitsCreationData : Array ) -> Array:
	var playerUnits__ := []
	for unitDatum in unitsCreationData:
		assert( unitDatum is UnitCreationDatumGd )
		var fileName = _game._module.getUnitFilename( unitDatum.name )
		if fileName.empty():
			continue

		var unitNode__ = load( fileName ).instance()
		unitNode__.set_name( "player_%s" % [unitDatum.name] )

		playerUnits__.append( unitNode__ )
	return playerUnits__


func _clearGame():
	yield( get_tree(), "idle_frame" )
	if _game.currentLevel != null:
		yield( _levelLoader.unloadLevel(), "completed" )
	if _game._module:
		_game.setCurrentModule( null )
	_game._playerManager.setPlayerUnits( [] )


