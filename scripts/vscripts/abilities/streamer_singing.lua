-- Singing (Пение) - ультимейт способность R для героя "Стример"
-- Герой начинает петь (чаннелинг), создавая AoE область вокруг себя
-- Наносит чистый урон каждую секунду врагам в области
-- Герой может двигаться (не прерывается движением)
-- Прерывается сайленсом или станом
-- Aghanim Scepter: увеличивает радиус и урон
-- Aghanim Shard: добавляет волны как у Sand King Epicenter

streamer_singing = class({})

-- Подключаем модификатор
LinkLuaModifier("modifier_streamer_singing", "abilities/modifiers/modifier_streamer_singing", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_streamer_singing_scepter", "abilities/modifiers/modifier_streamer_singing", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Константы способности
--------------------------------------------------------------------------------
local ABILITY_PROPERTIES = {
    BASE_RADIUS = 500,              -- Базовый радиус
    SCEPTER_RADIUS_BONUS = 250,     -- Бонус радиуса от септера (+250)
    BASE_DAMAGE = 70,               -- Базовый урон в секунду (уровень 1)
    MAX_HP_DAMAGE_PCT = 2.0,        -- 2% от max HP врага
    DAMAGE_INTERVAL = 1.0,          -- Интервал нанесения урона
    WAVE_INTERVAL = 1.5,            -- Интервал между волнами (для Shard)
    WAVE_SPEED = 500,               -- Скорость распространения волн
    SCEPTER_BONUS_DAMAGE = 40,      -- +40 чистого урона в сек от септера
    SCEPTER_SLOW_PCT = 25           -- -25% скорости врагам от септера
}

--------------------------------------------------------------------------------
-- Инициализация способности
--------------------------------------------------------------------------------
function streamer_singing:Precache(context)
    -- Основные эффекты
    PrecacheResource("particle", "particles/basic_ambient/basic_ambient.vpcf", context)
    PrecacheResource("particle", "particles/basic_explosion/basic_explosion.vpcf", context)
    -- Эффекты для волн (Shard) - используем Sand King частицы
    PrecacheResource("particle", "particles/units/heroes/hero_sandking/sandking_epicenter.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_sandking/sandking_epicenter_ring.vpcf", context)
    -- Звуки
    PrecacheResource("sound", "Hero_Morphling.Replicate", context)
    PrecacheResource("sound", "Hero_Sandking.Epicenter", context)
end

--------------------------------------------------------------------------------
-- Свойства способности
--------------------------------------------------------------------------------
function streamer_singing:GetBehavior()
    -- DOTA_ABILITY_BEHAVIOR_CHANNELLED - чаннелинг
    -- DOTA_ABILITY_BEHAVIOR_NO_TARGET - без цели
    -- DOTA_ABILITY_BEHAVIOR_DONT_CANCEL_MOVEMENT - не отменяется движением
    return DOTA_ABILITY_BEHAVIOR_CHANNELLED + DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_DONT_CANCEL_MOVEMENT
end

function streamer_singing:GetChannelTime()
    return self:GetDuration()
end

--------------------------------------------------------------------------------
-- Получение значений из KeyValues
--------------------------------------------------------------------------------
function streamer_singing:GetDuration()
    -- Длительность: 6 сек на всех уровнях
    return 6.0
end

function streamer_singing:GetBaseRadius()
    return self:GetSpecialValueFor("radius") or ABILITY_PROPERTIES.BASE_RADIUS
end

function streamer_singing:GetCurrentRadius()
    local caster = self:GetCaster()
    local base_radius = self:GetBaseRadius()
    
    -- Проверяем Aghanim Scepter (+250 радиуса)
    if caster and not caster:IsNull() and caster:HasScepter() then
        local scepter_bonus = self:GetSpecialValueFor("scepter_radius_bonus") or ABILITY_PROPERTIES.SCEPTER_RADIUS_BONUS
        return base_radius + scepter_bonus
    end
    
    return base_radius
end

function streamer_singing:GetDamagePerSecond()
    local level = self:GetLevel()
    local base_damage = self:GetSpecialValueFor("damage_per_second") or (ABILITY_PROPERTIES.BASE_DAMAGE + (level - 1) * 40)
    
    -- Проверяем Aghanim Scepter (+40 урона)
    local caster = self:GetCaster()
    if caster and not caster:IsNull() and caster:HasScepter() then
        local scepter_bonus = self:GetSpecialValueFor("scepter_bonus_damage") or ABILITY_PROPERTIES.SCEPTER_BONUS_DAMAGE
        base_damage = base_damage + scepter_bonus
    end
    
    return base_damage
end

function streamer_singing:GetMaxHpDamagePercent()
    local base_pct = self:GetSpecialValueFor("max_health_damage_pct") or ABILITY_PROPERTIES.MAX_HP_DAMAGE_PCT
    
    -- Проверяем талант 25 уровня (+3% от max HP)
    local caster = self:GetCaster()
    if caster and not caster:IsNull() then
        local talent = caster:FindAbilityByName("special_bonus_streamer_8")
        if talent and talent:GetLevel() > 0 then
            base_pct = base_pct + talent:GetSpecialValueFor("value")
        end
    end
    
    return base_pct
end

function streamer_singing:HasSilenceImmunity()
    local caster = self:GetCaster()
    if caster and not caster:IsNull() then
        local talent = caster:FindAbilityByName("special_bonus_streamer_7")
        if talent and talent:GetLevel() > 0 then
            return true
        end
    end
    return false
end

function streamer_singing:GetWaveSpeed()
    return self:GetSpecialValueFor("wave_speed") or ABILITY_PROPERTIES.WAVE_SPEED
end

--------------------------------------------------------------------------------
-- Запуск способности
--------------------------------------------------------------------------------
function streamer_singing:OnSpellStart()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Применяем модификатор пения
    local modifier = caster:AddNewModifier(
        caster,
        self,
        "modifier_streamer_singing",
        {}
    )
    
    if modifier then
        -- Звук начала пения
        caster:EmitSound("Hero_Morphling.Replicate")
        
        -- Визуальный эффект начала
        local particle = ParticleManager:CreateParticle(
            "particles/basic_explosion/basic_explosion.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            caster
        )
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

--------------------------------------------------------------------------------
-- Завершение чаннелинга
--------------------------------------------------------------------------------
function streamer_singing:OnChannelFinish(bInterrupted)
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Удаляем модификатор
    caster:RemoveModifierByName("modifier_streamer_singing")
    
    -- Звук окончания
    caster:StopSound("Hero_Morphling.Replicate")
    caster:EmitSound("Hero_Morphling.Replicate.Death")
    
    -- Сообщение если прервано
    if bInterrupted then
        print("[Streamer Singing] Пение прервано!")
    end
end

--------------------------------------------------------------------------------
-- Проверка доступности способности
--------------------------------------------------------------------------------
function streamer_singing:CastFilterResult()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return UF_FAIL_CUSTOM
    end
    
    -- Проверяем что герой не в стане или сайленсе
    if caster:IsStunned() or caster:IsSilenced() then
        return UF_FAIL_CUSTOM
    end
    
    return UF_SUCCESS
end

function streamer_singing:GetCustomCastError()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return "#dota_hud_error_no_caster"
    end
    
    if caster:IsStunned() then
        return "#dota_hud_error_stunned"
    end
    
    if caster:IsSilenced() then
        return "#dota_hud_error_silenced"
    end
    
    return ""
end

--------------------------------------------------------------------------------
-- Обработка повышения уровня
--------------------------------------------------------------------------------
function streamer_singing:OnUpgrade()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Обновляем активный модификатор если есть
    local modifier = caster:FindModifierByName("modifier_streamer_singing")
    if modifier then
        modifier:ForceRefresh()
    end
end

--------------------------------------------------------------------------------
-- Получение информации о способности для интерфейса
--------------------------------------------------------------------------------
function streamer_singing:GetAOERadius()
    return self:GetCurrentRadius()
end

-- Проверка наличия Shard
function streamer_singing:HasShardUpgrade()
    local caster = self:GetCaster()
    if caster and not caster:IsNull() then
        return caster:HasShard()
    end
    return false
end

-- Проверка наличия Scepter
function streamer_singing:HasScepterUpgrade()
    local caster = self:GetCaster()
    if caster and not caster:IsNull() then
        return caster:HasScepter()
    end
    return false
end
