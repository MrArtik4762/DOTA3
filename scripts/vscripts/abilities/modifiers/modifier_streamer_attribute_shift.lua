-- Modifier для способности Attribute Shift героя "Стример"
-- Обрабатывает перекачку статов STR <-> AGI

modifier_streamer_attribute_shift = class({})

--------------------------------------------------------------------------------
-- Константы модификатора
--------------------------------------------------------------------------------
local MODIFIER_PROPERTIES = {
    SHIFT_RATE = 1,              -- Скорость перекачки (статов за тик)
    SHIFT_INTERVAL = 0.1,        -- Интервал между тиками (в секундах)
    MIN_STATS = 1                -- Минимальное количество статов для перекачки
}

--------------------------------------------------------------------------------
-- Объявление функций модификатора
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:IsHidden()
    return false
end

function modifier_streamer_attribute_shift:IsDebuff()
    return false
end

function modifier_streamer_attribute_shift:IsPurgable()
    return false
end

function modifier_streamer_attribute_shift:DestroyOnExpire()
    return false
end

function modifier_streamer_attribute_shift:GetAttributes()
    return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

--------------------------------------------------------------------------------
-- Инициализация модификатора
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:OnCreated(kv)
    if not IsServer() then
        return
    end
    
    -- Инициализируем переменные
    self.shift_rate = self:GetAbility():GetSpecialValueFor("shift_rate") or MODIFIER_PROPERTIES.SHIFT_RATE
    self.shift_interval = self:GetAbility():GetSpecialValueFor("shift_interval") or MODIFIER_PROPERTIES.SHIFT_INTERVAL
    
    -- Тип перекачки: "str_to_agi" или "agi_to_str"
    self.shift_type = kv.shift_type or "str_to_agi"
    
    -- Счётчики перекачанных статов
    self.bonus_agility = 0
    self.bonus_strength = 0
    
    -- Запускаем таймер перекачки
    self:StartIntervalThink(self.shift_interval)
end

function modifier_streamer_attribute_shift:OnRefresh(kv)
    if not IsServer() then
        return
    end
    
    -- Обновляем параметры при рефреше
    self.shift_rate = self:GetAbility():GetSpecialValueFor("shift_rate") or self.shift_rate
    self.shift_interval = self:GetAbility():GetSpecialValueFor("shift_interval") or self.shift_interval
    
    if kv.shift_type then
        self.shift_type = kv.shift_type
    end
end

function modifier_streamer_attribute_shift:OnDestroy()
    if not IsServer() then
        return
    end
    
    -- При удалении модификатора возвращаем статы в исходное состояние
    local parent = self:GetParent()
    
    if parent and not parent:IsNull() then
        -- Убираем бонусные статы
        if self.bonus_agility > 0 then
            parent:ModifyAgility(-self.bonus_agility)
        end
        if self.bonus_strength > 0 then
            parent:ModifyStrength(-self.bonus_strength)
        end
    end
end

--------------------------------------------------------------------------------
-- Логика перекачки статов
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:OnIntervalThink()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    
    if not parent or parent:IsNull() or not ability or ability:IsNull() then
        self:Destroy()
        return
    end
    
    -- Проверяем, активна ли способность (тоггл)
    if not ability:GetToggleState() then
        return
    end
    
    -- Проверяем достаточно ли маны
    local mana_cost = ability:GetManaCost(-1) * self.shift_interval
    if parent:GetMana() < mana_cost then
        -- Недостаточно маны - выключаем тоггл
        ability:ToggleAbility()
        return
    end
    
    -- Трата маны
    parent:SpendMana(mana_cost, ability)
    
    -- Получаем базовые статы (без бонусов от этого модификатора)
    local base_strength = parent:GetBaseStrength()
    local base_agility = parent:GetBaseAgility()
    
    -- Логика перекачки
    if self.shift_type == "str_to_agi" then
        -- Перекачка STR -> AGI
        if base_strength > MODIFIER_PROPERTIES.MIN_STATS then
            local amount_to_shift = math.min(self.shift_rate, base_strength - MODIFIER_PROPERTIES.MIN_STATS)
            
            -- Уменьшаем STR и увеличиваем AGI
            parent:ModifyStrength(-amount_to_shift)
            parent:ModifyAgility(amount_to_shift)
            
            -- Обновляем счётчики
            self.bonus_agility = self.bonus_agility + amount_to_shift
            if self.bonus_strength > 0 then
                self.bonus_strength = math.max(0, self.bonus_strength - amount_to_shift)
            end
        else
            -- Недостаточно STR для перекачки
            ability:ToggleAbility()
        end
        
    elseif self.shift_type == "agi_to_str" then
        -- Перекачка AGI -> STR
        if base_agility > MODIFIER_PROPERTIES.MIN_STATS then
            local amount_to_shift = math.min(self.shift_rate, base_agility - MODIFIER_PROPERTIES.MIN_STATS)
            
            -- Уменьшаем AGI и увеличиваем STR
            parent:ModifyAgility(-amount_to_shift)
            parent:ModifyStrength(amount_to_shift)
            
            -- Обновляем счётчики
            self.bonus_strength = self.bonus_strength + amount_to_shift
            if self.bonus_agility > 0 then
                self.bonus_agility = math.max(0, self.bonus_agility - amount_to_shift)
            end
        else
            -- Недостаточно AGI для перекачки
            ability:ToggleAbility()
        end
    end
end

--------------------------------------------------------------------------------
-- Визуальные эффекты
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:GetEffectName()
    -- Эффект в зависимости от типа перекачки
    if self.shift_type == "str_to_agi" then
        return "particles/basic_trail/basic_trail.vpcf"  -- Синий эффект для AGI
    else
        return "particles/basic_rope/basic_rope.vpcf"    -- Красный эффект для STR
    end
end

function modifier_streamer_attribute_shift:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
-- Дополнительные свойства модификатора
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS
    }
end

function modifier_streamer_attribute_shift:GetModifierBonusStats_Strength()
    if IsServer() then
        return self.bonus_strength or 0
    end
    return 0
end

function modifier_streamer_attribute_shift:GetModifierBonusStats_Agility()
    if IsServer() then
        return self.bonus_agility or 0
    end
    return 0
end

--------------------------------------------------------------------------------
-- Вспомогательные функции
--------------------------------------------------------------------------------
function modifier_streamer_attribute_shift:GetShiftType()
    return self.shift_type or "str_to_agi"
end

function modifier_streamer_attribute_shift:SetShiftType(new_type)
    if new_type == "str_to_agi" or new_type == "agi_to_str" then
        self.shift_type = new_type
    end
end

function modifier_streamer_attribute_shift:GetBonusAgility()
    return self.bonus_agility or 0
end

function modifier_streamer_attribute_shift:GetBonusStrength()
    return self.bonus_strength or 0
end