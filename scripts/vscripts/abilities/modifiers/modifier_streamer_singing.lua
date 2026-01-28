-- Modifier для ультимейта Singing (Пение) героя "Стример"
-- Применяется на героя во время пения
-- Каждую секунду наносит урон врагам в радиусе
-- Проверяет Aghanim Scepter/Shard для дополнительных эффектов
-- Обрабатывает прерывание (стан, сайленс)

modifier_streamer_singing = class({})

--------------------------------------------------------------------------------
-- Константы модификатора
--------------------------------------------------------------------------------
local MODIFIER_PROPERTIES = {
    BASE_RADIUS = 500,              -- Базовый радиус
    SCEPTER_RADIUS_BONUS = 250,     -- Бонус радиуса от септера
    DAMAGE_INTERVAL = 1.0,          -- Интервал нанесения урона
    WAVE_INTERVAL = 1.5,            -- Интервал между волнами (Shard)
    WAVE_SPEED = 500,               -- Скорость распространения волн
    WAVE_WIDTH = 100,               -- Ширина волны
    SCEPTER_BONUS_DAMAGE = 40,      -- Бонус урона от септера
    SCEPTER_SLOW_PCT = 25           -- Замедление от септера
}

--------------------------------------------------------------------------------
-- Объявление функций модификатора
--------------------------------------------------------------------------------
function modifier_streamer_singing:IsHidden()
    return false
end

function modifier_streamer_singing:IsDebuff()
    return false
end

function modifier_streamer_singing:IsPurgable()
    return false
end

function modifier_streamer_singing:DestroyOnExpire()
    return true
end

function modifier_streamer_singing:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

--------------------------------------------------------------------------------
-- Инициализация модификатора
--------------------------------------------------------------------------------
function modifier_streamer_singing:OnCreated(kv)
    if not IsServer() then
        return
    end
    
    local ability = self:GetAbility()
    local parent = self:GetParent()
    
    if not ability or ability:IsNull() then
        return
    end
    
    -- Инициализируем параметры
    self.damage_per_second = ability:GetDamagePerSecond()
    self.current_radius = ability:GetCurrentRadius()
    self.damage_interval = MODIFIER_PROPERTIES.DAMAGE_INTERVAL
    self.max_hp_damage_pct = ability:GetMaxHpDamagePercent()
    
    -- Счётчики для интервалов
    self.damage_timer = 0
    self.wave_timer = 0
    
    -- Список активных волн (для Shard)
    self.active_waves = {}
    
    -- Проверяем апгрейды
    self.has_scepter = parent:HasScepter()
    self.has_shard = parent:HasShard()
    
    -- Создаём основной эффект AoE
    self:CreateAmbientEffect()
    
    -- Запускаем таймер для урона и волн
    self:StartIntervalThink(0.1)
end

function modifier_streamer_singing:OnRefresh(kv)
    if not IsServer() then
        return
    end
    
    local ability = self:GetAbility()
    local parent = self:GetParent()
    
    if not ability or ability:IsNull() then
        return
    end
    
    -- Обновляем параметры
    self.damage_per_second = ability:GetDamagePerSecond()
    self.current_radius = ability:GetCurrentRadius()
    self.max_hp_damage_pct = ability:GetMaxHpDamagePercent()
    self.has_scepter = parent:HasScepter()
    self.has_shard = parent:HasShard()
    
    -- Обновляем эффект если изменился радиус
    self:UpdateAmbientEffect()
end

function modifier_streamer_singing:OnDestroy()
    if not IsServer() then
        return
    end
    
    -- Останавливаем звук
    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        parent:StopSound("Hero_Morphling.Replicate")
    end
    
    -- Удаляем эффекты
    self:DestroyAmbientEffect()
    
    -- Очищаем волны
    self:ClearAllWaves()
end

--------------------------------------------------------------------------------
-- Создание и управление эффектами
--------------------------------------------------------------------------------
function modifier_streamer_singing:CreateAmbientEffect()
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    -- Создаём частицу AoE эффекта
    self.ambient_particle = ParticleManager:CreateParticle(
        "particles/basic_ambient/basic_ambient.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
    
    -- Настраиваем размер эффекта в зависимости от радиуса
    local radius = self.current_radius or MODIFIER_PROPERTIES.BASE_RADIUS
    ParticleManager:SetParticleControl(self.ambient_particle, 1, Vector(radius, radius, radius))
end

function modifier_streamer_singing:UpdateAmbientEffect()
    if self.ambient_particle then
        local radius = self.current_radius or MODIFIER_PROPERTIES.BASE_RADIUS
        ParticleManager:SetParticleControl(self.ambient_particle, 1, Vector(radius, radius, radius))
    end
end

function modifier_streamer_singing:DestroyAmbientEffect()
    if self.ambient_particle then
        ParticleManager:DestroyParticle(self.ambient_particle, false)
        ParticleManager:ReleaseParticleIndex(self.ambient_particle)
        self.ambient_particle = nil
    end
end

--------------------------------------------------------------------------------
-- Основная логика таймера
--------------------------------------------------------------------------------
function modifier_streamer_singing:OnIntervalThink()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    
    if not parent or parent:IsNull() then
        self:Destroy()
        return
    end
    
    if not ability or ability:IsNull() then
        self:Destroy()
        return
    end
    
    -- Проверяем прерывание (стан или сайленс)
    if self:IsInterrupted(parent) then
        self:Destroy()
        return
    end
    
    -- Обновляем таймеры
    local delta_time = 0.1
    self.damage_timer = self.damage_timer + delta_time
    self.wave_timer = self.wave_timer + delta_time
    
    -- Наносим урон по интервалу
    if self.damage_timer >= self.damage_interval then
        self:ApplyDamageToEnemies()
        self.damage_timer = 0
    end
    
    -- Создаём волну если есть Shard
    if self.has_shard and self.wave_timer >= MODIFIER_PROPERTIES.WAVE_INTERVAL then
        self:CreateWave()
        self.wave_timer = 0
    end
    
    -- Обновляем существующие волны
    self:UpdateWaves(delta_time)
end

--------------------------------------------------------------------------------
-- Проверка прерывания
--------------------------------------------------------------------------------
function modifier_streamer_singing:IsInterrupted(parent)
    local ability = self:GetAbility()
    
    -- Проверяем талант 25 уровня (не прерывается сайленсом)
    local has_silence_immunity = false
    if ability and not ability:IsNull() then
        has_silence_immunity = ability:HasSilenceImmunity()
    end
    
    -- Проверяем стан
    if parent:IsStunned() then
        print("[Streamer Singing] Прервано оглушением!")
        return true
    end
    
    -- Проверяем сайленс (если нет таланта)
    if not has_silence_immunity and parent:IsSilenced() then
        print("[Streamer Singing] Прервано безмолвием!")
        return true
    end
    
    -- Проверяем что способность всё ещё в чаннеле
    if ability and not ability:IsNull() then
        if not ability:IsChanneling() then
            print("[Streamer Singing] Чаннелинг завершён!")
            return true
        end
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Нанесение урона врагам
--------------------------------------------------------------------------------
function modifier_streamer_singing:ApplyDamageToEnemies()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    
    if not parent or parent:IsNull() then
        return
    end
    
    if not ability or ability:IsNull() then
        return
    end
    
    local radius = self.current_radius or MODIFIER_PROPERTIES.BASE_RADIUS
    local base_damage = (self.damage_per_second or 70) * self.damage_interval
    local max_hp_pct = (self.max_hp_damage_pct or 2.0) / 100  -- Конвертируем % в десятичную дробь
    
    -- Получаем значения для Scepter
    local has_scepter = self.has_scepter
    local slow_pct = 0
    if has_scepter then
        slow_pct = ability:GetSpecialValueFor("scepter_slow_pct") or MODIFIER_PROPERTIES.SCEPTER_SLOW_PCT
    end
    
    -- Находим врагов в радиусе
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        parent:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    -- Наносим урон каждому врагу
    for _, enemy in pairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            -- Рассчитываем урон: базовый + % от max HP
            local max_hp_damage = enemy:GetMaxHealth() * max_hp_pct
            local total_damage = base_damage + max_hp_damage
            
            self:DealPureDamage(enemy, total_damage, ability)
            
            -- Применяем замедление от Scepter
            if has_scepter and slow_pct > 0 then
                -- Создаём модификатор замедления (если нужно)
                -- Или используем существующий
            end
        end
    end
    
    -- Визуальный эффект пульсации
    self:CreatePulseEffect()
end

--------------------------------------------------------------------------------
-- Нанесение чистого урона
--------------------------------------------------------------------------------
function modifier_streamer_singing:DealPureDamage(target, damage, ability)
    if not target or target:IsNull() then
        return
    end
    
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end
    
    -- Создаём таблицу урона
    local damage_table = {
        victim = target,
        attacker = parent,
        damage = damage,
        damage_type = DAMAGE_TYPE_PURE,
        ability = ability,
        damage_flags = DOTA_DAMAGE_FLAG_NONE
    }
    
    -- Применяем урон
    ApplyDamage(damage_table)
    
    -- Визуальный эффект урона
    local particle = ParticleManager:CreateParticle(
        "particles/basic_explosion/basic_explosion_flash.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:ReleaseParticleIndex(particle)
end

--------------------------------------------------------------------------------
-- Создание эффекта пульсации
--------------------------------------------------------------------------------
function modifier_streamer_singing:CreatePulseEffect()
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    local radius = self.current_radius or MODIFIER_PROPERTIES.BASE_RADIUS
    
    -- Создаём кольцо пульсации
    local particle = ParticleManager:CreateParticle(
        "particles/basic_explosion/basic_explosion.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
    
    ParticleManager:SetParticleControl(particle, 1, Vector(radius * 0.5, radius * 0.5, radius * 0.5))
    ParticleManager:ReleaseParticleIndex(particle)
end

--------------------------------------------------------------------------------
-- Система волн (Aghanim Shard)
-- Волны каждые 1.5 сек, радиус 700, урон 120 + 40% AGI
--------------------------------------------------------------------------------
function modifier_streamer_singing:CreateWave()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    
    if not parent or parent:IsNull() then
        return
    end
    
    -- Получаем параметры Shard из ability
    local shard_wave_radius = 700
    local shard_wave_damage = 120
    local shard_agility_pct = 0.4
    
    if ability and not ability:IsNull() then
        shard_wave_radius = ability:GetSpecialValueFor("shard_wave_radius") or shard_wave_radius
        shard_wave_damage = ability:GetSpecialValueFor("shard_wave_damage") or shard_wave_damage
        shard_agility_pct = ability:GetSpecialValueFor("shard_agility_pct") or shard_agility_pct
    end
    
    -- Рассчитываем урон волны: 120 + 40% от AGI
    local caster_agility = parent:GetAgility()
    local wave_damage = shard_wave_damage + (caster_agility * shard_agility_pct)
    
    -- Создаём новую волну
    local wave = {
        radius = 0,
        max_radius = shard_wave_radius,
        speed = MODIFIER_PROPERTIES.WAVE_SPEED,
        particle = nil,
        damage_applied = {},
        damage = wave_damage
    }
    
    -- Создаём эффект волны
    wave.particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_sandking/sandking_epicenter_ring.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
    
    ParticleManager:SetParticleControl(wave.particle, 1, Vector(50, 50, 50))
    
    -- Добавляем волну в список
    table.insert(self.active_waves, wave)
    
    -- Звук волны
    parent:EmitSound("Hero_Sandking.Epicenter")
    
    print(string.format("[Streamer Singing] Создана волна! Урон: %d", wave_damage))
end

function modifier_streamer_singing:UpdateWaves(delta_time)
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    local ability = self:GetAbility()
    local parent_origin = parent:GetAbsOrigin()
    
    -- Обновляем каждую волну
    for i = #self.active_waves, 1, -1 do
        local wave = self.active_waves[i]
        
        -- Увеличиваем радиус волны
        wave.radius = wave.radius + (wave.speed * delta_time)
        
        -- Обновляем эффект волны
        if wave.particle then
            ParticleManager:SetParticleControl(wave.particle, 1, Vector(wave.radius, wave.radius, wave.radius))
        end
        
        -- Наносим урон врагам на пути волны
        self:ApplyWaveDamage(wave, parent_origin, ability)
        
        -- Удаляем волну если достигла максимального радиуса
        if wave.radius >= wave.max_radius then
            if wave.particle then
                ParticleManager:DestroyParticle(wave.particle, false)
                ParticleManager:ReleaseParticleIndex(wave.particle)
            end
            table.remove(self.active_waves, i)
        end
    end
end

function modifier_streamer_singing:ApplyWaveDamage(wave, origin, ability)
    local parent = self:GetParent()
    
    if not parent or parent:IsNull() then
        return
    end
    
    -- Находим врагов в зоне волны (кольцо)
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        origin,
        nil,
        wave.radius + MODIFIER_PROPERTIES.WAVE_WIDTH,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    -- Наносим урон врагам в зоне волны (магический урон от Shard)
    for _, enemy in pairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            -- Проверяем что враг в кольце волны
            local distance = (enemy:GetAbsOrigin() - origin):Length2D()
            local is_in_wave = math.abs(distance - wave.radius) <= MODIFIER_PROPERTIES.WAVE_WIDTH
            
            -- Проверяем что урон ещё не наносился этой волне
            local enemy_id = enemy:entindex()
            
            if is_in_wave and not wave.damage_applied[enemy_id] then
                -- Урон волны: 120 + 40% AGI (магический)
                local wave_damage = wave.damage or 120
                
                local damage_table = {
                    victim = enemy,
                    attacker = parent,
                    damage = wave_damage,
                    damage_type = DAMAGE_TYPE_MAGICAL,
                    ability = ability
                }
                
                ApplyDamage(damage_table)
                wave.damage_applied[enemy_id] = true
                
                -- Визуальный эффект
                local particle = ParticleManager:CreateParticle(
                    "particles/basic_explosion/basic_explosion_flash.vpcf",
                    PATTACH_ABSORIGIN_FOLLOW,
                    enemy
                )
                ParticleManager:ReleaseParticleIndex(particle)
            end
        end
    end
end

function modifier_streamer_singing:ClearAllWaves()
    for _, wave in pairs(self.active_waves or {}) do
        if wave.particle then
            ParticleManager:DestroyParticle(wave.particle, false)
            ParticleManager:ReleaseParticleIndex(wave.particle)
        end
    end
    self.active_waves = {}
end

--------------------------------------------------------------------------------
-- Объявление функций
--------------------------------------------------------------------------------
function modifier_streamer_singing:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
    }
end

--------------------------------------------------------------------------------
-- Небольшой замедление во время пения (для баланса)
--------------------------------------------------------------------------------
function modifier_streamer_singing:GetModifierMoveSpeedBonus_Percentage()
    return -10  -- -10% скорости движения
end

--------------------------------------------------------------------------------
-- Визуальные эффекты для интерфейса
--------------------------------------------------------------------------------
function modifier_streamer_singing:GetEffectName()
    return "particles/basic_ambient/basic_ambient.vpcf"
end

function modifier_streamer_singing:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_streamer_singing:GetStatusEffectName()
    return "particles/basic_ambient/basic_ambient.vpcf"
end

function modifier_streamer_singing:StatusEffectPriority()
    return 10
end

--------------------------------------------------------------------------------
-- Текстура для интерфейса
--------------------------------------------------------------------------------
function modifier_streamer_singing:GetTexture()
    return "morphling_morph_str"
end
