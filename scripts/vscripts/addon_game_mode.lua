-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

-- Letter Invoker Game Mode System
if LetterInvokerGameMode == nil then
	LetterInvokerGameMode = class({})
end

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]

	-- Precache для Letter Invoker
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_quas_orb.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_wex_orb.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_exort_orb.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_elder_titan/elder_titan_earth_splitter.vpcf", context)
	PrecacheResource("particle", "particles/items2_fok_lotus_hood.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/vanguard_aura.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/pipe_of_lightning.vpcf", context)

	-- Precache для invoked способностей
	for _, ability in pairs({
		"invoked_fortress_of_structure",
		"invoked_structural_momentum",
		"invoked_momentum_construct",
		"invoked_velocity_storm",
		"invoked_swift_strike",
		"invoked_burning_momentum",
		"invoked_flaming_shield",
		"invoked_healing_flames",
		"invoked_inferno_blast",
		"invoked_triune_force",
		"invoked_adaptive_force",
		"invoked_kinetic_burst",
		"invoked_swift_recovery",
		"invoked_flame_dash"
	}) do
		PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_emp.vpcf", context)
	end
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	print( "Template addon is loaded." )
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	-- Принудительный выбор Морфа (который теперь Стример)
	GameRules:GetGameModeEntity():SetCustomGameForceHero("npc_dota_hero_morphling")
	
	-- Отключаем время выбора героя
	GameRules:SetHeroSelectionTime(0)
	GameRules:SetStrategyTime(0)
	GameRules:SetShowcaseTime(0)
	GameRules:SetPreGameTime(30)

	-- Инициализация системы Letter Invoker
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(LetterInvokerGameMode, 'OnNPCSpawned'), self)
	ListenToGameEvent('entity_killed', Dynamic_Wrap(LetterInvokerGameMode, 'OnEntityKilled'), self)

	-- Listen for game state change
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(LetterInvokerGameMode, 'OnGameRulesStateChange'), self)

	-- Регистрация источников звука для Letter Invoker
	LinkLuaModifier("modifier_invoked_fortress_armor", "abilities/invoked/invoked_fortress_of_structure", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_invoked_fortress_armor_aura", "abilities/invoked/invoked_fortress_of_structure", LUA_MODIFIER_MOTION_NONE)

	print('[Letter Invoker] GameMode initialized')
end

-- Evaluate the state of the game
function CAddonTemplateGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

-- Обработчик спавна NPC
function LetterInvokerGameMode:OnNPCSpawned(event)
	local spawnedUnit = EntIndexToHScript(event.entindex)
	if not spawnedUnit or not spawnedUnit:IsHero() then return end
	
	-- Проверяем что это Letter Invoker или Streamer (Morphling)
	local heroName = spawnedUnit:GetName()
	if heroName == "npc_dota_hero_arteman" or heroName == "npc_dota_hero_letter_invoker" or heroName == "npc_dota_hero_morphling" then
		-- Инициализируем LetterInvokerCore если еще не инициализирован
		if LetterInvokerCore then
			LetterInvokerCore:Init()
		end
	end
end

-- Обработчик смерти NPC
function LetterInvokerGameMode:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript(event.entindex)
	if not killedUnit then return end
	
	-- Очистка ресурсов при смерти
	if killedUnit:IsHero() then
		-- Логика очистки при смерти героя
	end
end

-- Обработчик изменения состояния игры
function LetterInvokerGameMode:OnGameRulesStateChange()
	local state = GameRules:State_Get()
	
	if state == DOTA_GAMERULES_STATE_PRE_GAME then
		-- Предстартовая инициализация
		print('[Letter Invoker] Pre-game initialization')
		
		-- Инициализируем ядро системы
		if LetterInvokerCore then
			LetterInvokerCore:Init()
			print('[Letter Invoker] LetterInvokerCore initialized')
		end
	elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		print('[Letter Invoker] Game in progress')
	end
end