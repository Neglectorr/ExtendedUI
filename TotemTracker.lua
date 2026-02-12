TOTEM3D = {}

TOTEM3D.modelPaths = {
  [1] = "creature\\spells\\draeneitotem_fire.m2",
  [2] = "creature\\spells\\draeneitotem_earth.m2",
  [3] = "creature\\spells\\draeneitotem_water.m2",
  [4] = "creature\\spells\\draeneitotem_air.m2",
}
TOTEM3D.frame = nil
TOTEM3D.models = {}

local TotemRangeUtil = _G.TotemRangeUtil
local totemTicker = nil

local function StripTotemRank(name)
  if not name then return nil end
  local out = name
  out = out:gsub("%s%(Rank %d+%)", "")
  out = out:gsub(" %u+$", "")
  out = out:gsub("^%s*(.-)%s*$", "%1")
  return out
end

-- Zoekt een button (en indien gewenst de bovenliggende) waarop deze spell staat,
-- werkt altijd ook zonder GetAction() per button.
local function FindSnapButtonForTotem(totemName)
  local possibleBars = {
    "ActionButton",                     -- HOOFDBAR
    "MultiBarBottomLeftButton",         -- direct erboven, fallback/snappoint
    "MultiBarBottomRightButton",        -- evt tweede laag
    "MultiBarRightButton",              -- etc.
    "MultiBarLeftButton"
  }

  local matchBtn, aboveBtn = nil, nil

  -- 1. Scan primaire bar eerst: zoek actionbutton waar de spell staat.
  for i = 1, 12 do
    local btnName = "ActionButton"..i
    local btn = _G[btnName]
    if btn then
      local actionId = btn.action or btn:GetID()
      actionId = _G["ActionButton_GetPagedID"] and ActionButton_GetPagedID(btn) or actionId
      if actionId then
        local typ, spellId = GetActionInfo(actionId)
        if typ == "spell" and spellId then
          local btnSpellName = GetSpellInfo(spellId)
          if btnSpellName and StripTotemRank(btnSpellName) == StripTotemRank(totemName) then
            matchBtn = btn
            -- Check of er een MultiBarButton boven zit als snappoint:
            aboveBtn = _G["MultiBarBottomLeftButton"..i]
            if aboveBtn and aboveBtn:IsShown() then
              return aboveBtn -- snap naar deze
            end
            aboveBtn = _G["MultiBarBottomRightButton"..i]
            if aboveBtn and aboveBtn:IsShown() then
              return aboveBtn
            end
            -- Anders toon gewoon op matchBtn
            return matchBtn
          end
        end
      end
    end
  end

  -- 2. Scan overige bars (MultiBarBottomLeft enz.); hier geen 'bovenliggend' snappoint nodig
  for bn = 2, #possibleBars do
    local bar = possibleBars[bn]
    for i = 1, 12 do
      local btnName = bar..i
      local btn = _G[btnName]
      if btn then
        local actionId = btn.action or btn:GetID()
        actionId = _G["ActionButton_GetPagedID"] and ActionButton_GetPagedID(btn) or actionId
        if actionId then
          local typ, spellId = GetActionInfo(actionId)
          if typ == "spell" and spellId then
            local btnSpellName = GetSpellInfo(spellId)
            if btnSpellName and StripTotemRank(btnSpellName) == StripTotemRank(totemName) then
              return btn
            end
          end
        end
      end
    end
  end

  return nil
end

function TOTEM3D:CreateFrame()
  if self.frame then return end
  self.frame = CreateFrame("Frame", "EUI_Totem3DTrackerFrame", UIParent)
  self.frame:SetSize(4*56, 200)
  self.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
  self.frame:Hide()
  self.models = {}
  for slot=1,4 do
    local m = CreateFrame("PlayerModel", nil, self.frame)
    m:SetSize(56, 200)
    m:SetModelScale(1)
    m:SetCamDistanceScale(2)
    m:SetFacing(0)
    m:SetAlpha(1)
    m:Hide()
    self.models[slot] = m
  end
end

function TOTEM3D:UpdateTotems()
  self:CreateFrame()
  self.frame:Show()
  for slot = 1, 4 do
    local haveTotem, totemName, startTime, duration, _ = GetTotemInfo(slot)
    local m = self.models[slot]
    if haveTotem and duration and duration > 0 and TOTEM3D.modelPaths[slot] and totemName and totemName ~= "" then
      local btn = FindSnapButtonForTotem(totemName)
      if btn then
        if not m:IsShown() then
          m:SetModel(TOTEM3D.modelPaths[slot])
          m:SetCamDistanceScale(2.1)
          m:SetPosition(0, 0, -1.7)
          m:SetFacing(0)
          m:SetAlpha(1)
          m:Show()
        end
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", btn, "TOP", 0, 0)
        if TotemRangeUtil and TotemRangeUtil.IsPlayerInRange and not TotemRangeUtil:IsPlayerInRange(slot) then
          m:SetAlpha(0.20)
        else
          m:SetAlpha(1)
        end
      else
        m:Hide()
      end
    else
      m:Hide()
    end
  end
end

function TOTEM3D:Show()
  self:CreateFrame()
  self.frame:Show()
  self:UpdateTotems()
end

function TOTEM3D:Hide()
  if self.frame then self.frame:Hide() end
  for i=1,4 do
    if self.models[i] then self.models[i]:Hide() end
  end
end

function TOTEM3D:StartTrackerLoop()
  if totemTicker then totemTicker:Cancel() end
  totemTicker = C_Timer.NewTicker(0.15, function()
    self:UpdateTotems()
  end)
end

function TOTEM3D:StopTrackerLoop()
  if totemTicker then totemTicker:Cancel() end
  if self.frame then self.frame:Hide() end
end

local function IsDBAvailable()
  return ExtendedUI_DB
    and ExtendedUI_DB.profile
    and ExtendedUI_DB.profile.global
end

function TOTEM3D:GetEnabled()
  if IsDBAvailable() then
    return ExtendedUI_DB.profile.global.totemTrackerEnabled and true or false
  end
  return self.enabled or false
end
function TOTEM3D:SetEnabled(state)
  self.enabled = state and true or false
  if IsDBAvailable() then
    ExtendedUI_DB.profile.global.totemTrackerEnabled = self.enabled
  end
  if self.enabled then
    self:Show()
    self:StartTrackerLoop()
  else
    self:Hide()
    self:StopTrackerLoop()
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
eventFrame:SetScript("OnEvent", function()
  if TOTEM3D.GetEnabled and TOTEM3D:GetEnabled() then
    TOTEM3D:Show()
    TOTEM3D:StartTrackerLoop()
  else
    TOTEM3D:Hide()
    TOTEM3D:StopTrackerLoop()
  end
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, addon)
  if addon == "ExtendedUI" then
    if ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global then
      TOTEM3D.enabled = ExtendedUI_DB.profile.global.totemTrackerEnabled and true or false
      if TOTEM3D.enabled then
        TOTEM3D:Show()
        TOTEM3D:StartTrackerLoop()
      else
        TOTEM3D:Hide()
        TOTEM3D:StopTrackerLoop()
      end
    end
  end
end)