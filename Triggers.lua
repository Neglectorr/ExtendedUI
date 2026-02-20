EUI_Triggers = {}
local T = EUI_Triggers

local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitThreatSituation = UnitThreatSituation
local UnitIsFriend = UnitIsFriend
local GetTotemInfo = GetTotemInfo
local GetItemCount = GetItemCount
local tonumber = tonumber
local GetTime = GetTime

local MAX_AURAS = 40

local function UnitHPPercent(unit)
  if not UnitExists(unit) then return nil end
  local hp = UnitHealth(unit)
  local maxhp = UnitHealthMax(unit)
  if not maxhp or maxhp == 0 then return nil end
  return (hp / maxhp) * 100
end

local function HasAura(unit, auraName)
  if not auraName or auraName == "" then return false end
  for i = 1, MAX_AURAS do
    local name = UnitBuff(unit, i)
    if not name then break end
    if name == auraName then
      return true
    end
  end
  return false
end

local function HasDebuff(unit, auraName)
  if not auraName or auraName == "" then return false end
  for i = 1, MAX_AURAS do
    local name = UnitDebuff(unit, i)
    if not name then break end
    if name == auraName then
      return true
    end
  end
  return false
end

local function GetItemCountSafe(itemId)
  local id = tonumber(itemId)
  if not id then return 0 end
  if GetItemCount then
    return GetItemCount(id) or 0
  end
  return 0
end

T.EVAL = {}

T.EVAL.NONE = function() return true end

T.EVAL.THREAT_AT_LEAST = function(rule)
  local min = tonumber(rule.params and rule.params.min) or 3
  if not UnitExists("target") then return false end
  local s = UnitThreatSituation and UnitThreatSituation("player", "target")
  if not s then return false end
  return s >= min
end

T.EVAL.TOTEM_SLOT_MISSING = function(rule)
  local slot = tonumber(rule.params and rule.params.totemSlot)
  if not slot then return false end
  local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
  return not (haveTotem and duration and duration > 0)
end

T.EVAL.TARGET_HP_BELOW = function(rule)
  local below = tonumber(rule.params and rule.params.below) or 20
  if not UnitExists("target") then return false end
  local p = UnitHPPercent("target")
  if not p then return false end
  return p < below
end

T.EVAL.ITEM_COUNT_BELOW = function(rule)
  local itemId = rule.params and rule.params.itemId
  local below = tonumber(rule.params and rule.params.below) or 5
  return GetItemCountSafe(itemId) < below
end

T.EVAL.MISSING_BUFF = function(rule)
  local unit = (rule.params and rule.params.unit) or "player"
  if unit ~= "player" and unit ~= "target" then unit = "player" end

  if unit == "target" then
    if not UnitExists("target") then return false end
    local friendlyOnly = rule.params and rule.params.targetFriendlyOnly
    if friendlyOnly and not UnitIsFriend("player", "target") then return false end
  end

  local aura = rule.params and rule.params.auraName
  return not HasAura(unit, aura)
end

T.EVAL.MISSING_DEBUFF_TARGET = function(rule)
  if not UnitExists("target") then return false end
  if UnitIsFriend("player", "target") then return false end
  local aura = rule.params and rule.params.auraName
  return not HasDebuff("target", aura)
end

local _evalCacheFrame = -1
local _evalCache = {}

function T.Evaluate(rule, context)
  if not rule or not rule.trigger then
    return false
  end

  -- Per-frame result cache: avoid re-evaluating the same rule in the same frame
  local frame = GetTime()
  if frame ~= _evalCacheFrame then
    _evalCacheFrame = frame
    wipe(_evalCache)
  end

  local cacheKey = rule
  local cached = _evalCache[cacheKey]
  if cached ~= nil then return cached end

  local fn = T.EVAL[rule.trigger]
  if not fn then
    _evalCache[cacheKey] = false
    return false
  end

  local ok = fn(rule, context)

  local inv = rule.params and rule.params.invert
  if inv and rule.trigger ~= "NONE" then
    ok = not ok
  end

  _evalCache[cacheKey] = ok
  return ok
end