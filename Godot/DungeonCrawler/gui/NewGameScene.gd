
extends Control

const SavingModuleGd         = preload("res://modules/SavingModule.gd")
const UtilityGd              = preload("res://Utility.gd")

const ModuleExtensions       = ["gd"]
const InvalidModuleString    = "..."

var m_params = {}                      setget deleted
var m_previousSceneFile                setget deleted
var m_module_                          setget setModule
var m_rpcTargets = []                  setget deleted # setRpcTargets


signal readyForGame( module_, playerUnitCreationData )
signal isReady() #TODO: consider using ready() signal of Node once it's available
signal finished()


func deleted(a):
	assert(false)


func _ready():
	m_params = SceneSwitcher.m_sceneParams
	assert(m_params != null)

	Connector.connectNewGameScene( self )

	moduleSelected( get_node("ModuleSelection/FileName").text )
	get_node("Lobby").connect("unitNumberChanged", self, "onUnitNumberChanged")

	if m_params["isHost"] == true:
		get_node("ModuleSelection/SelectModule").disabled = false

	Network.connect("nodeRegisteredClientsChanged", self, "onNodeRegisteredClientsChanged")
	if not Network.isServer():
		Network.rpc( "registerNodeForClient", get_path() )

	emit_signal("isReady")


func _exit_tree():
		if get_tree().has_network_peer():
			Network.rpc( "unregisterNodeForClient", get_path() )


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if m_module_ != null:
			m_module_.free()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		emit_signal("finished")
		accept_event()


func onNodeRegisteredClientsChanged( nodePath ):
	if nodePath == get_path():
		setRpcTargets( Network.m_nodesWithClients[nodePath] )


func onLeaveGamePressed():
	emit_signal("finished")


func onNetworkError( what ):
	emit_signal("finished")


slave func moduleSelected( moduleDataPath : String ):
	assert( moduleDataPath == InvalidModuleString or moduleDataPath.get_extension() in ModuleExtensions )
	clear()

	var moduleNode_ = null

	#TODO: handle selection gdscript files that take arguments for _init()
	var dataResource = load(moduleDataPath)
	if dataResource:
		var moduleData = load(moduleDataPath).new()
		if SavingModuleGd.verify( moduleData ):
			moduleNode_ = SavingModuleGd.new( moduleData, dataResource.resource_path )

	if not moduleNode_:
		UtilityGd.log("Incorrect module data file " + moduleDataPath)
		if Network.isServer():
			for id in m_rpcTargets:
				rpc_id(id, "moduleSelected", get_node("ModuleSelection/FileName").text )
		return


	setModule( moduleNode_ )
	get_node("ModuleSelection/FileName").text = moduleDataPath
	get_node("Lobby").setMaxUnits( m_module_.getPlayerUnitMax() )

	if Network.isServer():
		for id in m_rpcTargets:
			rpc_id(id, "moduleSelected", get_node("ModuleSelection/FileName").text )


func onUnitNumberChanged( number ):
	assert( number >= 0 )
	get_node("Buttons/StartGame").disabled = ( number == 0 or !Network.isServer() )


func clear():
	get_node("ModuleSelection/FileName").text = InvalidModuleString
	setModule( null )
	get_node("Lobby").clearUnits()


func onStartGamePressed():
	emit_signal("readyForGame", m_module_, $"Lobby".m_unitsCreationData)
	m_module_ = null  # release ownership


func setModule( moduleNode_ ):
	UtilityGd.setFreeing( m_module_ )
	m_module_ = moduleNode_
	get_node("Lobby").setModule( moduleNode_ )


func setRpcTargets( clientIds ):
	m_rpcTargets = clientIds
	$"Lobby".setRpcTargets( clientIds )


