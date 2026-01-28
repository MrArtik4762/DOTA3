-- Mystic Shot - способность Q для героя "Стример"
-- Линейный снаряд, наносящий урон с скалированием от ловкости
-- При наличии таланта вызывает Adaptive Strike

streamer_mystic_shot = class({})

--------------------------------------------------------------------------------
-- Константы способности
--------------------------------------------------------------------------------
local ABILITY_PROPERTIES = {
    PROJECTILE_SPEED = 1800,        -- Скорость снаряда
    PROJECTILE_WIDTH = 110,         -- Ширина снаряда
    BASE_DAMAGE = 80,               -- Базовый урон (уровень 1)
    AGILITY_MULTIPLIER = 0.7,       -- Множитель урона от ловкости (70%)
    ADAPTIVE_STRIKE_DAMAGE = 100,   -- Базовый урон Adaptive Strike
    ADAPTIVE_STRIKE_AGI_PCT = 0.5,  -- 50% от AGI для Adaptive Strike
    TALENT_RANGE_BONUS = 200        -- Бонус дальности от таланта
}

--------------------------------------------------------------------------------
-- Инициализация способности
--------------------------------------------------------------------------------
function streamer_mystic_shot:Precache(context)
    PrecacheResource("particle", "particles/basic_projectile/basic_projectile.vpcf", context)
    PrecacheResource("sound", "Hero_Morphling.AdaptiveStrike", context)
end

--------------------------------------------------------------------------------
-- Получение значений из KeyValues
--------------------------------------------------------------------------------
function streamer_mystic_shot:GetProjectileSpeed()
    return self:GetSpecialValueFor("projectile_speed") or ABILITY_PROPERTIES.PROJECTILE_SPEED
end

function streamer_mystic_shot:GetProjectileWidth()
    return self:GetSpecialValueFor("projectile_width") or ABILITY_PROPERTIES.PROJECTILE_WIDTH
end

--------------------------------------------------------------------------------
-- Получение дальности с учетом талантов
--------------------------------------------------------------------------------
function streamer_mystic_shot:GetCastRange(vLocation, hTarget)
    local base_range = self.BaseClass.GetCastRange(self, vLocation, hTarget)
    local caster = self:GetCaster()
    
    -- Проверяем талант на +200 дальности
    if caster and not caster:IsNull() then
        local talent = caster:FindAbilityByName("special_bonus_streamer_1")
        if talent and talent:GetLevel() > 0 then
            base_range = base_range + ABILITY_PROPERTIES.TALENT_RANGE_BONUS
        end
    end
    
    return base_range
end

--------------------------------------------------------------------------------
-- Запуск способности
--------------------------------------------------------------------------------
function streamer_mystic_shot:OnSpellStart()
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Получаем направление к точке прицеливания
    local caster_origin = caster:GetAbsOrigin()
    local direction = (target_point - caster_origin):Normalized()
    direction.z = 0  -- Убираем вертикальную составляющую
    
    -- Создаём линейный снаряд
    local projectile_info = {
        EffectName = "particles/basic_projectile/basic_projectile.vpcf",
        Ability = self,
        vSpawnOrigin = caster_origin,
        vVelocity = direction * self:GetProjectileSpeed(),
        fDistance = self:GetCastRange(target_point, caster) + 100,  -- Дальность + запас
        fStartRadius = self:GetProjectileWidth(),
        fEndRadius = self:GetProjectileWidth(),
        Source = caster,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        bProvidesVision = true,
        iVisionTeamNumber = caster:GetTeamNumber(),
        iVisionRadius = 300
    }
    
    ProjectileManager:CreateLinearProjectile(projectile_info)
    
    -- Звук выстрела
    caster:EmitSound("Hero_MorphWave.Projectile")
end

--------------------------------------------------------------------------------
-- Обработка попадания снаряда
--------------------------------------------------------------------------------
function streamer_mystic_shot:OnProjectileHit(hTarget, vLocation)
    -- Если цель nil или недействительна, прекращаем
    if not hTarget or hTarget:IsNull() or not hTarget:IsAlive() then
        return false
    end
    
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return false
    end
    
    -- Проверяем можно ли применить к цели
    if hTarget:IsInvulnerable() or hTarget:IsOutOfGame() then
        return false
    end
    
    -- Рассчитываем урон
    local base_damage = self:GetSpecialValueFor("base_damage") or ABILITY_PROPERTIES.BASE_DAMAGE
    local agi_multiplier = self:GetSpecialValueFor("damage_per_agility") or ABILITY_PROPERTIES.AGILITY_MULTIPLIER
    local caster_agility = caster:GetAgility()
    
    -- Добавляем бонус урона от таланта 15 уровня
    local talent_damage = 0
    local talent = caster:FindAbilityByName("special_bonus_streamer_4")
    if talent and talent:GetLevel() > 0 then
        talent_damage = talent:GetSpecialValueFor("value")
    end
    
    local total_damage = base_damage + (caster_agility * agi_multiplier) + talent_damage
    
    -- Наносим урон
    local damage_table = {
        victim = hTarget,
        attacker = caster,
        damage = total_damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self
    }
    
    ApplyDamage(damage_table)
    
    -- Визуальный эффект попадания
    local particle = ParticleManager:CreateParticle(
        "particles/basic_explosion/basic_explosion.vpcf", 
        PATTACH_ABSORIGIN_FOLLOW, 
        hTarget
    )
    ParticleManager:ReleaseParticleIndex(particle)
    
    -- Звук попадания
    hTarget:EmitSound("Hero_Morphling.ProjectileImpact")
    
    -- Проверяем талант на 10 уровне и вызываем Adaptive Strike
    self:CheckAndCastAdaptiveStrike(hTarget)
    
    -- Снаряд уничтожается при первом попадании
    return true
end

--------------------------------------------------------------------------------
-- Проверка таланта и вызов Adaptive Strike
-- Урон: 100 + 50% от AGI
-- Тип урона: магический если AGI > STR, физический если STR > AGI
--------------------------------------------------------------------------------
function streamer_mystic_shot:CheckAndCastAdaptiveStrike(hTarget)
    local caster = self:GetCaster()
    
    if not caster or caster:IsNull() then
        return
    end
    
    -- Проверяем наличие таланта special_bonus_streamer_2
    local talent = caster:FindAbilityByName("special_bonus_streamer_2")
    if not talent or talent:GetLevel() == 0 then
        return
    end
    
    -- Рассчитываем урон Adaptive Strike: 100 + 50% от AGI
    local base_damage = self:GetSpecialValueFor("adaptive_strike_damage") or ABILITY_PROPERTIES.ADAPTIVE_STRIKE_DAMAGE
    local agi_pct = self:GetSpecialValueFor("adaptive_strike_agility_pct") or ABILITY_PROPERTIES.ADAPTIVE_STRIKE_AGI_PCT
    local caster_agility = caster:GetAgility()
    
    local adaptive_damage = base_damage + (caster_agility * agi_pct)
    
    -- Определяем тип урона на основе статов
    local agility = caster:GetAgility()
    local strength = caster:GetStrength()
    
    local damage_type
    if agility > strength then
        damage_type = DAMAGE_TYPE_MAGICAL
    else
        damage_type = DAMAGE_TYPE_PHYSICAL
    end
    
    -- Наносим урон
    local damage_table = {
        victim = hTarget,
        attacker = caster,
        damage = adaptive_damage,
        damage_type = damage_type,
        ability = self
    }
    
    ApplyDamage(damage_table)
    
    -- Эффект для визуальной индикации Adaptive Strike
    local particle = ParticleManager:CreateParticle(
        "particles/basic_explosion/basic_explosion_flash.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        hTarget
    )
    ParticleManager:ReleaseParticleIndex(particle)
    
    hTarget:EmitSound("Hero_Morphling.AdaptiveStrike")
    
    -- Сообщение для отладки
    local damage_type_name = (damage_type == DAMAGE_TYPE_MAGICAL) and "магический" or "физический"
    print(string.format("[Adaptive Strike] Урон: %d (%s)", adaptive_damage, damage_type_name))
end