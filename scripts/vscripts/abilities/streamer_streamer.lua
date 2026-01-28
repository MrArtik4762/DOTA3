-- Streamer (Стример) - пассивная способность E для героя "Стример"
-- За каждый килл героя начисляется +1 стак "подписчиков"
-- Каждый стак дает бонус к ловкости
-- Стаки сохраняются навсегда

streamer_streamer = class({})

-- Подключаем модификатор
LinkLuaModifier("modifier_streamer_streamer_passive", "abilities/modifiers/modifier_streamer_streamer_passive", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Константы способности
--------------------------------------------------------------------------------
local ABILITY_PROPERTIES = {
    AGILITY_PER_STACK = 1,          -- Бонус ловкости за стак
    SPELL_AMP_PER_STACK = 0.3,      -- 0.3% spell amp за стак
    SUBSCRIBER_STACKS_SAVE = true   -- Стаки сохраняются между играми (в рамках матча)
}

--------------------------------------------------------------------------------
-- Инициализация способности
--------------------------------------------------------------------------------
function streamer_streamer:Precache(context)
    PrecacheResource("particle", "particles/generic_gameplay/rune_double_damage_owner.vpcf", context)
    PrecacheResource("sound", "Hero_Morphling.LevelUp", context)
end

--------------------------------------------------------------------------------
-- Свойства способности
--------------------------------------------------------------------------------
function streamer_streamer:GetIntrinsicModifierName()
    return "modifier_streamer_streamer_passive"
end

function streamer_streamer:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_PASSIVE
end

--------------------------------------------------------------------------------
-- Получение значений из KeyValues
--------------------------------------------------------------------------------
function streamer_streamer:GetAgilityPerStack()
    return self:GetSpecialValueFor("agility_per_stack") or ABILITY_PROPERTIES.AGILITY_PER_STACK
end

function streamer_streamer:GetSpellAmpPerStack()
    local caster = self:GetCaster()
    local base_amp = self:GetSpecialValueFor("spell_amp_per_stack") or ABILITY_PROPERTIES.SPELL_AMP_PER_STACK
    
    -- Проверяем талант на +0.5% spell amp за стак
    if caster and not caster:IsNull() then
        local talent = caster:FindAbilityByName("special_bonus_streamer_5")
        if talent and talent:GetLevel() > 0 then
            return talent:GetSpecialValueFor("value")
        end
    end
    
    return base_amp
end

function streamer_streamer:GetStacksPerKill()
    local caster = self:GetCaster()
    local base_stacks = 1
    
    -- Проверяем талант на +2 стака за килл
    if caster and not caster:IsNull() then
        local talent = caster:FindAbilityByName("special_bonus_streamer_6")
        if talent and talent:GetLevel() > 0 then
            return talent:GetSpecialValueFor("value")
        end
    end
    
    return base_stacks
end

--------------------------------------------------------------------------------
-- Вспомогательные функции для работы со стаками
--------------------------------------------------------------------------------

-- Получить текущее количество стаков подписчиков
function streamer_streamer:GetSubscriberStacks(caster)
    if not caster or caster:IsNull() then
        return 0
    end
    
    local modifier = caster:FindModifierByName("modifier_streamer_streamer_passive")
    if modifier then
        return modifier:GetStackCount()
    end
    
    return 0
end

-- Добавить стак подписчиков
function streamer_streamer:AddSubscriberStack(caster)
    if not caster or caster:IsNull() then
        return
    end
    
    local modifier = caster:FindModifierByName("modifier_streamer_streamer_passive")
    if modifier then
        -- Получаем количество стаков за килл (с учетом таланта)
        local stacks_to_add = self:GetStacksPerKill()
        
        for i = 1, stacks_to_add do
            modifier:AddStack()
        end
        
        -- Звук и эффект при получении стака
        caster:EmitSound("Hero_Morphling.LevelUp")
        
        local particle = ParticleManager:CreateParticle(
            "particles/generic_gameplay/rune_double_damage_owner.vpcf",
            PATTACH_OVERHEAD_FOLLOW,
            caster
        )
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

-- Получить общий бонус ловкости от всех стаков
function streamer_streamer:GetTotalAgilityBonus(caster)
    local stacks = self:GetSubscriberStacks(caster)
    local agility_per_stack = self:GetAgilityPerStack()
    return stacks * agility_per_stack
end

-- Получить общий бонус spell amp от всех стаков
function streamer_streamer:GetTotalSpellAmpBonus(caster)
    local stacks = self:GetSubscriberStacks(caster)
    local spell_amp_per_stack = self:GetSpellAmpPerStack()
    return stacks * spell_amp_per_stack
end

--------------------------------------------------------------------------------
-- Обработка событий
--------------------------------------------------------------------------------

-- Функция вызывается из модификатора при убийстве героя
function streamer_streamer:OnHeroKilledByOwner(killed_unit)
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    if not killed_unit or killed_unit:IsNull() then
        return
    end
    
    -- Проверяем что убитый - герой и враг
    if not killed_unit:IsRealHero() then
        return
    end
    
    if killed_unit:GetTeamNumber() == caster:GetTeamNumber() then
        return
    end
    
    -- Добавляем стак подписчиков
    self:AddSubscriberStack(caster)
    
    -- Сообщение в консоль для отладки
    local stacks = self:GetSubscriberStacks(caster)
    print(string.format("[Streamer] Новый подписчик! Всего подписчиков: %d", stacks))
end

--------------------------------------------------------------------------------
-- Обработка повышения уровня
--------------------------------------------------------------------------------
function streamer_streamer:OnUpgrade()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Обновляем модификатор при повышении уровня
    local modifier = caster:FindModifierByName("modifier_streamer_streamer_passive")
    if modifier then
        modifier:ForceRefresh()
    end
end
