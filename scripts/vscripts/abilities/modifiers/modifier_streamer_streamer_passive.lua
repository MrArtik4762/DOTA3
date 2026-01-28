-- Modifier для пассивной способности Streamer (Стример)
-- Хранит количество стаков "подписчиков" и применяет бонус к ловкости
-- Обрабатывает событие убийства героя

modifier_streamer_streamer_passive = class({})

--------------------------------------------------------------------------------
-- Константы модификатора
--------------------------------------------------------------------------------
local MODIFIER_PROPERTIES = {
    SAVE_STACKS = true  -- Стаки сохраняются между смертями
}

--------------------------------------------------------------------------------
-- Объявление функций модификатора
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:IsHidden()
    return false
end

function modifier_streamer_streamer_passive:IsDebuff()
    return false
end

function modifier_streamer_streamer_passive:IsPurgable()
    return false
end

function modifier_streamer_streamer_passive:DestroyOnExpire()
    return false
end

function modifier_streamer_streamer_passive:GetAttributes()
    return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

--------------------------------------------------------------------------------
-- Инициализация модификатора
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:OnCreated(kv)
    if not IsServer() then
        return
    end
    
    -- Инициализируем счётчик стаков
    self.stack_count = 0
    
    -- Получаем бонус ловкости за стак из способности
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        self.agility_per_stack = ability:GetSpecialValueFor("agility_per_stack") or 1
    else
        self.agility_per_stack = 1
    end
    
    -- Подписываемся на событие убийства героя
    self:StartIntervalThink(0.1)
end

function modifier_streamer_streamer_passive:OnRefresh(kv)
    if not IsServer() then
        return
    end
    
    -- Обновляем параметры при рефреше
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        self.agility_per_stack = ability:GetSpecialValueFor("agility_per_stack") or self.agility_per_stack
    end
end

function modifier_streamer_streamer_passive:OnDestroy()
    if not IsServer() then
        return
    end
    
    -- Отписываемся от событий
    if self.event_listener then
        StopListeningToGameEvent(self.event_listener)
        self.event_listener = nil
    end
end

--------------------------------------------------------------------------------
-- Логика работы с событиями
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:OnIntervalThink()
    -- Проверяем события убийства через поиск в радиусе (альтернативный метод)
    -- В реальном проекте лучше использовать ListenToGameEvent
    
    -- Для корректной работы подписываемся на событие один раз
    if not self.event_subscribed then
        self:SubscribeToEvents()
        self.event_subscribed = true
        self:StartIntervalThink(-1)  -- Останавливаем таймер
    end
end

function modifier_streamer_streamer_passive:SubscribeToEvents()
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    -- Получаем способность
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end
    
    -- Сохраняем ссылку для использования в обработчике
    self.ability_reference = ability
end

--------------------------------------------------------------------------------
-- Добавление стака
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:AddStack()
    if not IsServer() then
        return
    end
    
    self.stack_count = self.stack_count + 1
    self:SetStackCount(self.stack_count)
    
    -- Обновляем бонусные статы
    self:ForceRefresh()
end

-- Установить количество стаков (для загрузки сохранённых данных)
function modifier_streamer_streamer_passive:SetStacks(stacks)
    if not IsServer() then
        return
    end
    
    self.stack_count = math.max(0, stacks)
    self:SetStackCount(self.stack_count)
    self:ForceRefresh()
end

-- Получить количество стаков
function modifier_streamer_streamer_passive:GetStacks()
    return self.stack_count or 0
end

--------------------------------------------------------------------------------
-- Обработка убийства героя
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:OnHeroKilled(params)
    if not IsServer() then
        return
    end
    
    local parent = self:GetParent()
    local ability = self:GetAbility()
    
    if not parent or parent:IsNull() then
        return
    end
    
    if not ability or ability:IsNull() then
        return
    end
    
    -- Проверяем что убийца - наш владелец
    local attacker = params.attacker
    if not attacker or attacker:IsNull() then
        return
    end
    
    if attacker ~= parent then
        return
    end
    
    -- Проверяем что убитый - вражеский герой
    local killed_unit = params.target
    if not killed_unit or killed_unit:IsNull() then
        return
    end
    
    if not killed_unit:IsRealHero() then
        return
    end
    
    if killed_unit:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end
    
    -- Добавляем стак
    self:AddStack()
    
    -- Вызываем функцию способности для дополнительной логики
    if ability.OnHeroKilledByOwner then
        ability:OnHeroKilledByOwner(killed_unit)
    end
end

--------------------------------------------------------------------------------
-- Объявление функций для бонусов
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
        MODIFIER_EVENT_ON_HERO_KILLED
    }
end

--------------------------------------------------------------------------------
-- Бонус к ловкости
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:GetModifierBonusStats_Agility()
    if not IsServer() then
        return 0
    end
    
    local stacks = self.stack_count or 0
    local agility_per_stack = self.agility_per_stack or 1
    
    return stacks * agility_per_stack
end

--------------------------------------------------------------------------------
-- Бонус к Spell Amp
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:GetModifierSpellAmplify_Percentage()
    if not IsServer() then
        return 0
    end
    
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return 0
    end
    
    local stacks = self.stack_count or 0
    local spell_amp_per_stack = ability:GetSpellAmpPerStack()
    
    return stacks * spell_amp_per_stack
end

--------------------------------------------------------------------------------
-- Обработка события убийства героя
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:OnHeroKilled(params)
    if not IsServer() then
        return
    end
    
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    -- Проверяем что убийца - наш владелец
    if params.attacker ~= parent then
        return
    end
    
    -- Проверяем что убитый - вражеский герой
    local killed_unit = params.unit
    if not killed_unit or killed_unit:IsNull() then
        return
    end
    
    if not killed_unit:IsRealHero() then
        return
    end
    
    if killed_unit:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end
    
    -- Добавляем стак подписчиков
    self:AddStack()
    
    -- Эффект получения подписчика
    local particle = ParticleManager:CreateParticle(
        "particles/generic_gameplay/rune_double_damage_owner.vpcf",
        PATTACH_OVERHEAD_FOLLOW,
        parent
    )
    ParticleManager:ReleaseParticleIndex(particle)
    
    parent:EmitSound("Hero_Morphling.LevelUp")
    
    -- Сообщение для отладки
    print(string.format("[Streamer Passive] Новый подписчик! Всего: %d", self.stack_count))
end

--------------------------------------------------------------------------------
-- Визуальные эффекты
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:GetEffectName()
    -- Небольшой эффект в зависимости от количества стаков
    if self.stack_count >= 10 then
        return "particles/basic_ambient/basic_ambient.vpcf"
    end
    return nil
end

function modifier_streamer_streamer_passive:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
-- Текстура и описание для интерфейса
--------------------------------------------------------------------------------
function modifier_streamer_streamer_passive:GetTexture()
    return "morphling_morph_agi"
end
