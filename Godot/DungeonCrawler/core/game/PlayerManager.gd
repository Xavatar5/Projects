extends Node

const PlayerAgentGd          = preload("res://core/PlayerAgent.gd")
const GlobalGd               = preload("res://core/GlobalNames.gd")
const PlayerUnitGd           = preload("./PlayerUnit.gd")
const SetWrapperGd           = preload("res://addons/TypeWrappers/SetWrapper.gd")

const NoOwnerId = 0

var m_playerIds : SetWrapperGd = SetWrapperGd.new()   setget deleted, getPlayerIds
var m_playerUnits : Array = []         setget deleted # setPlayerUnits


signal playerUnitsChanged( playerUnits )


func deleted(_a):
	assert(false)


func _enter_tree():
	if is_network_master():
		Network.connect( "clientListChanged", self, "_adjustToClients" )
		connect( "playerUnitsChanged", self, "_assignUnitsToPlayers" )


func _ready():
	call_deferred( "createAgent" )


func setPlayerUnits( units : Array ):
	for unit in units:
		assert( unit is PlayerUnitGd )
	removePlayerUnits()
	m_playerUnits = units
	emit_signal("playerUnitsChanged", m_playerUnits)


func removePlayerUnits():
	m_playerUnits = []
	emit_signal("playerUnitsChanged", m_playerUnits)


func setPlayerIds( ids : Array ):
	m_playerIds.reset( ids )


func _adjustToClients( clients : Dictionary ):
	var playersToRemove : Array = []
	for playerId in m_playerIds.m_array:
		if not clients.has( playerId ):
			playersToRemove.append( playerId )

	m_playerIds.remove( playersToRemove )


func getPlayerIds():
	return m_playerIds.m_array.duplicate()


func getPlayerUnitNodes():
	var nodes = []
	for playerUnit in m_playerUnits:
		nodes.append( playerUnit.m_unitNode_ )
	return nodes


func createAgent():
	var networkId = get_tree().get_network_unique_id()

	var agent = PlayerAgentGd.new()
	agent.name = str( networkId )
	add_child( agent )
	agent.set_network_master( get_tree().get_network_unique_id() )

	if is_network_master():
		agent.connect( "ready",        self, "assignToAgent",     [networkId] )
		agent.connect( "tree_exiting", self, "unassignFromAgent", [networkId] )


func assignToAgent( id : int ):
	assert( has_node( str(id) ) )
	get_node( str(id) ).assignUnits( _unitsForAgent( id ) )


func unassignFromAgent( id : int ):
	assert( has_node( str(id) ) )
	get_node( str(id) ).unassignUnits( _unitsForAgent( id ) )


func _assignUnitsToPlayers( playerUnits : Array ):
	for agent in get_tree().get_nodes_in_group( GlobalGd.Groups.PlayerAgents ):
		assignToAgent( int( agent.name ) )


func _unitsForAgent( agentId : int ) -> Array:
	var units = []
	for playerUnit in m_playerUnits:
		if playerUnit.m_owner == agentId:
			units.append( playerUnit.m_unitNode_ )
	return units

