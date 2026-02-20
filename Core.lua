ExtendedUI = ExtendedUI or {}
local EUI = ExtendedUI

local GetTime = GetTime
local pairs = pairs
local tostring = tostring
local type = type

EUI.name = "ExtendedUI"
EUI.version = "0.3.6"
EUI.BAR_PREFIX = {
  [1] = "ActionButton",
  [2] = "MultiBarBottomLeftButton",
  [3] = "MultiBarBottomRightButton",
  [4] = "MultiBarRightButton",
  [5] = "MultiBarLeftButton",
}

EUI.BAR_MIN = 1
EUI.BAR_MAX = 5
EUI.SLOTS_PER_BAR = 12
EUI.RULES_PER_SLOT = 3

EUI.LANE = { [1] = "A", [2] = "B", [3] = "C" }
EUI.LANE_EFFECTS = {
  A = { NONE = true, GLOW_BORDER = true, AUTOCAST_RINGS = true, AUTOCAST_SPARKLES = true },
  B = { NONE = true, FLASH = true },
  C = { NONE = true, ICON_TINT = true },
}

local function DeepCopy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = DeepCopy(v) end
  return o
end

local DEFAULT_RULE = {
  enabled = false,
  trigger = "NONE",
  params = { invert = false },
  effect = "NONE",
  effectParams = { dim50 = false, static = false, color = "GOLD", showAsProc = false },
  debugForceOn = false,
}

function EUI:DefaultRule() return DeepCopy(DEFAULT_RULE) end

function EUI:InitDB()
  ExtendedUI_DB = ExtendedUI_DB or {}
  ExtendedUI_DB.profile = ExtendedUI_DB.profile or {}
  local p = ExtendedUI_DB.profile
  p.global = p.global or { enabled = true, updateInterval = 0.10 }
  p.global.totemTrackerEnabled = p.global.totemTrackerEnabled or false
  p.global.procStackAnchor = p.global.procStackAnchor or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
  if p.global.oneBagEnabled == nil then p.global.oneBagEnabled = false end
  if p.global.lootToastEnabled == nil then p.global.lootToastEnabled = false end
  p.global.oneBagFrame = p.global.oneBagFrame or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
  p.global.lootToast = p.global.lootToast or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
  p.bars = p.bars or {}
  for barId = self.BAR_MIN, self.BAR_MAX do
    p.bars[barId] = p.bars[barId] or {}
    for slot = 1, self.SLOTS_PER_BAR do
      p.bars[barId][slot] = p.bars[barId][slot] or { rules = {} }
      local rules = p.bars[barId][slot].rules
      for r = 1, self.RULES_PER_SLOT do
        if not rules[r] then rules[r] = DeepCopy(DEFAULT_RULE) end
        if type(rules[r].params) ~= "table" then rules[r].params = {} end
        if rules[r].params.invert == nil then rules[r].params.invert = false else rules[r].params.invert = rules[r].params.invert and true or false end
        if type(rules[r].effectParams) ~= "table" then rules[r].effectParams = { dim50 = false, static = false, color = "GOLD", showAsProc = false } end
        if rules[r].effectParams.dim50 == nil then rules[r].effectParams.dim50 = false end
        if rules[r].effectParams.static == nil then rules[r].effectParams.static = false end
        if rules[r].effectParams.showAsProc == nil then rules[r].effectParams.showAsProc = false else rules[r].effectParams.showAsProc = rules[r].effectParams.showAsProc and true or false end
        if rules[r].effectParams.color == nil then
          local old = rules[r].effectParams.flashColor
          rules[r].effectParams.color = (type(old) == "string") and old or "GOLD"
          rules[r].effectParams.flashColor = nil
        end
        if type(rules[r].effectParams.color) ~= "string" then rules[r].effectParams.color = "GOLD" end
      end
    end
  end
end

function EUI:GetButtonFrame(barId, slot)
  local prefix = self.BAR_PREFIX[barId]
  if not prefix then return nil end
  return _G[prefix .. tostring(slot)]
end

-- ==== Overlay functions ====
function EUI:EnsureOverlay(btn)
  if not btn or btn.ExtendedUIOverlay then return end

  local o = CreateFrame("Frame", nil, btn)
  o:SetAllPoints(btn)
  o:SetFrameStrata(btn:GetFrameStrata())
  o:SetFrameLevel(btn:GetFrameLevel() + 50)

  o.glow = o:CreateTexture(nil, "OVERLAY")
  o.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  o.glow:SetBlendMode("ADD")
  o.glow:SetPoint("CENTER", o, "CENTER", 0, 0)
  o.glow:SetSize(70, 70)
  o.glow:Hide()

  o.ring1 = o:CreateTexture(nil, "OVERLAY")
  o.ring1:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  o.ring1:SetBlendMode("ADD")
  o.ring1:SetPoint("CENTER", o, "CENTER", 0, 0)
  o.ring1:SetSize(62, 62)
  o.ring1:Hide()

  o.ring2 = o:CreateTexture(nil, "OVERLAY")
  o.ring2:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  o.ring2:SetBlendMode("ADD")
  o.ring2:SetPoint("CENTER", o, "CENTER", 0, 0)
  o.ring2:SetSize(54, 54)
  o.ring2:Hide()

  o.flash = o:CreateTexture(nil, "OVERLAY")
  o.flash:SetAllPoints(o)
  o.flash:SetTexture("Interface\\Buttons\\WHITE8x8")
  o.flash:SetBlendMode("ADD")
  o.flash:Hide()

  local name = btn:GetName()
  o.icon = name and _G[name .. "Icon"] or nil

  btn.ExtendedUIOverlay = o
end
function EUI:ClearLane(btn, lane)
  local o = btn and btn.ExtendedUIOverlay
  if not o then return end
  if lane == "A" then
    if o.glow then o.glow:Hide() end
    if o.ring1 then o.ring1:Hide() end
    if o.ring2 then o.ring2:Hide() end
  elseif lane == "B" then
    if o.flash then o.flash:Hide() end
  elseif lane == "C" then
    if o.icon then
      o.icon:SetVertexColor(1, 1, 1, 1)
      o.icon:SetAlpha(1)
      if o.icon.SetDesaturated then o.icon:SetDesaturated(false) end
    end
  end
end

local function SlotHasAnyActiveEffect(slotCfg)
  if not slotCfg or not slotCfg.rules then return false end
  for i = 1, EUI.RULES_PER_SLOT do
    local rule = slotCfg.rules[i]
    if rule and rule.enabled and rule.effect and rule.effect ~= "NONE" then
      return true
    end
  end
  return false
end

function EUI:ApplySlot(barId, slot)
  local btn = self:GetButtonFrame(barId, slot)
  if not btn then return end
  if btn.IsShown and not btn:IsShown() then return end
  local p = ExtendedUI_DB.profile
  if not p.global.enabled then
    self:EnsureOverlay(btn)
    for _, lane in ipairs(self.LANE) do self:ClearLane(btn, lane) end
    return
  end
  local slotCfg = p.bars[barId] and p.bars[barId][slot]
  if not slotCfg or not slotCfg.rules then return end
  self:EnsureOverlay(btn)
  if not SlotHasAnyActiveEffect(slotCfg) then
    for _, lane in ipairs(self.LANE) do self:ClearLane(btn, lane) end
    return
  end
  local now = GetTime()
  for i = 1, self.RULES_PER_SLOT do
    local lane = self.LANE[i]
    self:ClearLane(btn, lane)
    local rule = slotCfg.rules[i]
    if rule and rule.enabled then
      local allowed = self.LANE_EFFECTS[lane] and self.LANE_EFFECTS[lane][rule.effect]
      if allowed then
        local ok
        if rule.debugForceOn then ok = true
        else ok = EUI_Triggers and EUI_Triggers.Evaluate and EUI_Triggers.Evaluate(rule, { barId = barId, slot = slot, button = btn }) or false end
        if ok and EUI_Effects and EUI_Effects.Apply then
          if not (lane == "A" and rule.effectParams and rule.effectParams.showAsProc) then
            EUI_Effects.Apply(rule, { barId = barId, slot = slot, button = btn, now = now, lane = lane, ruleIndex = i })
          end
        end
      end
    end
  end
end

function EUI:ApplyAll()
  for barId = self.BAR_MIN, self.BAR_MAX do
    for slot = 1, self.SLOTS_PER_BAR do
      self:ApplySlot(barId, slot)
    end
  end
  -- ProcHelper integration: show/update procs (requires ProcHelper.lua present)
  if ProcHelper and ProcHelper.Update then
    ProcHelper:Update()
  end
end

function EUI:StartEngine()
  if self.engine then return end
  local f = CreateFrame("Frame")
  self.engine = f
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("UNIT_AURA")
  f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
  f:RegisterEvent("BAG_UPDATE")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  local elapsed = 0
  local cachedInterval = 0.10
  f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < cachedInterval then return end
    elapsed = 0
    EUI:ApplyAll()
  end)
  f:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
      local g = ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global
      cachedInterval = (g and g.updateInterval) or 0.10
    end
    if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then return end
    EUI:ApplyAll()
  end)
end

SLASH_EXTENDEDUI1 = "/extendedUI"
SLASH_EXTENDEDUI2 = "/exui"
EUI._pendingMainToggle = false

local function TryToggleMainMenu()
  if EUI_Menu and EUI_Menu.ToggleHub then EUI_Menu.ToggleHub(); return true end
  return false
end

-- Slash command
SlashCmdList["EXTENDEDUI"] = function(_msg)
  if not TryToggleMainMenu() then
    EUI._pendingMainToggle = true
    print("ExtendedUI: loading menu...")
  end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, _, addon)
  if addon ~= "ExtendedUI" then return end
  EUI:InitDB()
  EUI:StartEngine()
  EUI:ApplyAll()
  if ExtendedUI and ExtendedUI.OneBag_SetEnabled and ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global then
    ExtendedUI:OneBag_SetEnabled(ExtendedUI_DB.profile.global.oneBagEnabled)
  end
  if EUI._pendingMainToggle then
    EUI._pendingMainToggle = false
    TryToggleMainMenu()
  end
end)

local btn = CreateFrame("Button", "EXUI_MinimapButton", Minimap)
btn:SetSize(32, 32)
btn:SetFrameStrata("HIGH")
btn:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", 6, 0)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn.icon = btn:CreateTexture(nil, "ARTWORK")
btn.icon:SetTexture(134429)
btn.icon:SetAllPoints(btn)
if btn.icon.SetMask then btn.icon:SetMask("Interface\\Minimap\\UI-Minimap-Background") end
btn.border = btn:CreateTexture(nil, "OVERLAY")
btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btn.border:SetBlendMode("ADD")
btn.border:ClearAllPoints()
btn.border:SetPoint("CENTER", btn, "CENTER", 10, -10)
btn.border:SetSize(54, 54)
btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("ExtendedUI Main Menu", 1, 1, 1)
  GameTooltip:AddLine("Left-click to Show/Hide", .8, .8, .8)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
btn:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" and EUI_Menu then
    EUI_Menu.ToggleHub()
  end
end)