-- Attribute Shift - способность W для героя "Стример"
-- Тоггл-способность для перекачки статов STR <-> AGI
-- Аналог способности Morphling

streamer_attribute_shift = class({})

-- Подключаем модификатор
LinkLuaModifier("modifier_streamer_attribute_shift", "abilities/modifiers/modifier_streamer_attribute_shift", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Константы способности
--------------------------------------------------------------------------------
local ABILITY_PROPERTIES = {
    DEFAULT_SHIFT_RATE = 1,         -- Статов за тик по умолчанию
    DEFAULT_SHIFT_INTERVAL = 0.1,   -- Интервал между тиками
    MIN_STATS = 1                    -- Минимальное количество статов
}

--------------------------------------------------------------------------------
-- Инициализация способности
--------------------------------------------------------------------------------
function streamer_attribute_shift:Precache(context)
    PrecacheResource("particle", "particles/basic_trail/basic_trail.vpcf", context)
    PrecacheResource("particle", "particles/basic_rope/basic_rope.vpcf", context)
    PrecacheResource("sound", "Hero_Morphling.AttributeShift", context)
end

--------------------------------------------------------------------------------
-- Свойства способности
--------------------------------------------------------------------------------
function streamer_attribute_shift:IsToggle()
    return true
end

function streamer_attribute_shift:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_TOGGLE + DOTA_ABILITY_BEHAVIOR_NO_TARGET
end

--------------------------------------------------------------------------------
-- Получение значений из KeyValues
--------------------------------------------------------------------------------
function streamer_attribute_shift:GetShiftRate()
    return self:GetSpecialValueFor("shift_rate") or ABILITY_PROPERTIES.DEFAULT_SHIFT_RATE
end

function streamer_attribute_shift:GetShiftInterval()
    return self:GetSpecialValueFor("shift_interval") or ABILITY_PROPERTIES.DEFAULT_SHIFT_INTERVAL
end

--------------------------------------------------------------------------------
-- Обработка переключения тоггла
--------------------------------------------------------------------------------
function streamer_attribute_shift:OnToggle()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Проверяем состояние тоггла
    local is_toggled_on = self:GetToggleState()
    
    if is_toggled_on then
        -- Тоггл включен - начинаем перекачку
        self:StartAttributeShift()
    else
        -- Тоггл выключен - останавливаем перекачку
        self:StopAttributeShift()
    end
end

--------------------------------------------------------------------------------
-- Начало перекачки статов
--------------------------------------------------------------------------------
function streamer_attribute_shift:StartAttributeShift()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Определяем направление перекачки на основе текущих статов
    local shift_type = self:DetermineShiftDirection()
    
    -- Проверяем возможность перекачки
    if not self:CanShift(shift_type) then
        -- Невозможно перекачать - выключаем тоггл
        self:ToggleAbility()
        self:SendErrorMessage("Недостаточно статов для перекачки")
        return
    end
    
    -- Удаляем старый модификатор если есть
    caster:RemoveModifierByName("modifier_streamer_attribute_shift")
    
    -- Применяем новый модификатор
    local modifier = caster:AddNewModifier(
        caster,
        self,
        "modifier_streamer_attribute_shift",
        { shift_type = shift_type }
    )
    
    if modifier then
        -- Звук начала перекачки
        caster:EmitSound("Hero_Morphling.AttributeShift")
        
        -- Визуальный эффект в зависимости от направления
        local particle_name
        if shift_type == "str_to_agi" then
            particle_name = "particles/basic_projectile/basic_projectile_launch.vpcf"
        else
            particle_name = "particles/basic_explosion/basic_explosion.vpcf"
        end
        
        local particle = ParticleManager:CreateParticle(
            particle_name,
            PATTACH_ABSORIGIN_FOLLOW,
            caster
        )
        ParticleManager:ReleaseParticleIndex(particle)
    else
        -- Не удалось создать модификатор - выключаем тоггл
        self:ToggleAbility()
    end
end

--------------------------------------------------------------------------------
-- Остановка перекачки статов
--------------------------------------------------------------------------------
function streamer_attribute_shift:StopAttributeShift()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Удаляем модификатор
    caster:RemoveModifierByName("modifier_streamer_attribute_shift")
    
    -- Звук остановки
    caster:EmitSound("Hero_Morphling.AttributeShift.Stop")
end

--------------------------------------------------------------------------------
-- Определение направления перекачки
--------------------------------------------------------------------------------
function streamer_attribute_shift:DetermineShiftDirection()
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return "str_to_agi"  -- По умолчанию
    end
    
    local strength = caster:GetStrength()
    local agility = caster:GetAgility()
    
    -- Если STR больше AGI - перекачиваем STR -> AGI
    -- Если AGI больше или равно STR - перекачиваем AGI -> STR
    if strength > agility then
        return "str_to_agi"
    else
        return "agi_to_str"
    end
end

--------------------------------------------------------------------------------
-- Проверка возможности перекачки
--------------------------------------------------------------------------------
function streamer_attribute_shift:CanShift(shift_type)
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return false
    end
    
    local base_strength = caster:GetBaseStrength()
    local base_agility = caster:GetBaseAgility()
    
    if shift_type == "str_to_agi" then
        -- Нужно минимум MIN_STATS + 1 STR для перекачки
        return base_strength > ABILITY_PROPERTIES.MIN_STATS
    elseif shift_type == "agi_to_str" then
        -- Нужно минимум MIN_STATS + 1 AGI для перекачки
        return base_agility > ABILITY_PROPERTIES.MIN_STATS
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Отправка сообщения об ошибке игроку
--------------------------------------------------------------------------------
function streamer_attribute_shift:SendErrorMessage(message)
    local player_id = self:GetCaster():GetPlayerOwnerID()
    if player_id and player_id >= 0 then
        -- Отправляем пользовательское сообщение об ошибке
        -- В реальном проекте можно использовать CustomGameEventManager
        print("[Attribute Shift Error] Player " .. player_id .. ": " .. message)
    end
end

--------------------------------------------------------------------------------
-- Вспомогательные функции для внешнего доступа
--------------------------------------------------------------------------------
function streamer_attribute_shift:IsShifting()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return false
    end
    
    return caster:HasModifier("modifier_streamer_attribute_shift")
end

function streamer_attribute_shift:GetCurrentShiftType()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return nil
    end
    
    local modifier = caster:FindModifierByName("modifier_streamer_attribute_shift")
    if modifier then
        return modifier:GetShiftType()
    end
    
    return nil
end

function streamer_attribute_shift:GetShiftedStats()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return { bonus_agility = 0, bonus_strength = 0 }
    end
    
    local modifier = caster:FindModifierByName("modifier_streamer_attribute_shift")
    if modifier then
        return {
            bonus_agility = modifier:GetBonusAgility(),
            bonus_strength = modifier:GetBonusStrength()
        }
    end
    
    return { bonus_agility = 0, bonus_strength = 0 }
end

--------------------------------------------------------------------------------
-- Обработка повышения уровня способности
--------------------------------------------------------------------------------
function streamer_attribute_shift:OnUpgrade()
    -- Обновляем параметры модификатора если он активен
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    local modifier = caster:FindModifierByName("modifier_streamer_attribute_shift")
    if modifier then
        modifier:OnRefresh({ shift_type = modifier:GetShiftType() })
    end
end

--------------------------------------------------------------------------------
-- Обработка событий героя
--------------------------------------------------------------------------------
function streamer_attribute_shift:OnOwnerSpawned()
    -- Сбрасываем состояние при возрождении
    if self:GetToggleState() then
        self:ToggleAbility()
    end
end

function streamer_attribute_shift:OnOwnerDied()
    -- Автоматически выключаем при смерти
    if self:GetToggleState() then
        self:ToggleAbility()
    end
end