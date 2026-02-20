TOTEM3D = {}

TOTEM3D.MODE_OFF = 0
TOTEM3D.MODE_3D = 1
TOTEM3D.MODE_ART = 2
TOTEM3D.modes = { "Uit", "3D models", "Art" }
TOTEM3D.mode = TOTEM3D.MODE_3D
TOTEM3D.selectedArtSet = TOTEM3D.selectedArtSet or 1

TOTEM3D.modelPaths = {
  [1] = "creature\\spells\\draeneitotem_fire.m2",
  [2] = "creature\\spells\\draeneitotem_earth.m2",
  [3] = "creature\\spells\\draeneitotem_water.m2",
  [4] = "creature\\spells\\draeneitotem_air.m2",
}

TOTEM3D.artPathsFunc = function(setNum)
  return {
    [1] = "Interface\\AddOns\\ExtendedUI\\TotemArt_Fire"..setNum..".png",
    [2] = "Interface\\AddOns\\ExtendedUI\\TotemArt_Earth"..setNum..".png",
    [3] = "Interface\\AddOns\\ExtendedUI\\TotemArt_Water"..setNum..".png",
    [4] = "Interface\\AddOns\\ExtendedUI\\TotemArt_Air"..setNum..".png",
  }
end

TOTEM3D.frame = nil
TOTEM3D.models = {}
TOTEM3D.arts = {}

local TotemRangeUtil = _G.TotemRangeUtil
local totemTicker = nil

local function IsInDungeon()
  local inInstance, instanceType = IsInInstance()
  return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
end

local function PlayerHasTotemBuff(slot)
  for i = 1, 40 do
    local name = UnitBuff("player", i)
    if name and name:lower():find("totem") then
      return true
    end
  end
  return false
end

local function ShouldFadeTotem(slot)
  if not TotemRangeUtil then return false end
  local inRange = TotemRangeUtil:IsPlayerInRange(slot)
  if inRange == nil then return false end -- position unknown, assume in range
  if not inRange then
    return true
  end
  if IsInDungeon() and not PlayerHasTotemBuff(slot) then
    return true
  end
  return false
end

local function StripTotemRank(name)
  if not name then return nil end
  local out = name
  out = out:gsub("%s%(Rank %d+%)", "")
  out = out:gsub(" %u+$", "")
  out = out:gsub("^%s*(.-)%s*$", "%1")
  return out
end

local function FindSnapButtonForTotem(totemName)
  local possibleBars = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton"
  }

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
            local aboveBtn = _G["MultiBarBottomLeftButton"..i]
            if aboveBtn and aboveBtn:IsShown() then return aboveBtn end
            aboveBtn = _G["MultiBarBottomRightButton"..i]
            if aboveBtn and aboveBtn:IsShown() then return aboveBtn end
            return btn
          end
        end
      end
    end
  end

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
  self.arts = {}
  self.frame:SetFrameStrata("BACKGROUND")
  self.frame:SetFrameLevel(0)
  for slot = 1, 4 do
    -- 3D Model
    local m = CreateFrame("PlayerModel", nil, self.frame)
    m:SetSize(56, 200)
    m:SetModelScale(1)
    m:SetCamDistanceScale(2)
    m:SetFacing(0)
    m:SetAlpha(1)
    m:Hide()
    self.models[slot] = m

    -- Art Texture + anim group
    local t = self.frame:CreateTexture(nil, "ARTWORK")
    t:SetSize(56, 100)
    t:SetAlpha(1)
    t:Hide()
    self.arts[slot] = t

     -- Fade/drop animatiegroep (val, shake, en fade)
    t.animGroup = t:CreateAnimationGroup()
    local shake = t.animGroup:CreateAnimation("Translation")
    shake:SetOffset(12, 0)
    shake:SetDuration(0.09)
    shake:SetOrder(1)
    local shakeback = t.animGroup:CreateAnimation("Translation")
    shakeback:SetOffset(-24, 0)
    shakeback:SetDuration(0.09)
    shakeback:SetOrder(2)
    local shakeend = t.animGroup:CreateAnimation("Translation")
    shakeend:SetOffset(12, 0)
    shakeend:SetDuration(0.09)
    shakeend:SetOrder(3)
    local drop = t.animGroup:CreateAnimation("Translation")
    drop:SetOffset(0, -150)
    drop:SetDuration(0.7)              -- snellere val
    drop:SetOrder(4)
    local fade = t.animGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.5)
    fade:SetOrder(5)
    fade:SetStartDelay(0.7)
    t.animGroup:SetScript("OnFinished", function()
      t:Hide()
      t:SetAlpha(1)
      t:SetPoint("BOTTOM", self.frame, "TOP", 0, 0)
      t.wasShown = nil
      t.isFading = nil
    end)
	
    -- Appear/spring anim (bij verschijnen)
    t.appearAnimGroup = t:CreateAnimationGroup()
	
	local springUp = t.appearAnimGroup:CreateAnimation("Translation")
	springUp:SetOffset(0, 10)        -- omhoog, tot 10 pixels boven anchor
	springUp:SetDuration(0.10)
	springUp:SetOrder(1)
	local landDown = t.appearAnimGroup:CreateAnimation("Translation")
	landDown:SetOffset(0, -10)       -- van +10 naar exact anchor
	landDown:SetDuration(0.07)
	landDown:SetOrder(2)
	local appearShake = t.appearAnimGroup:CreateAnimation("Translation")
	appearShake:SetOffset(10, 0)
	appearShake:SetDuration(0.04)
	appearShake:SetOrder(3)
	local appearShakeback = t.appearAnimGroup:CreateAnimation("Translation")
	appearShakeback:SetOffset(-20, 0)
	appearShakeback:SetDuration(0.04)
	appearShakeback:SetOrder(4)
	local appearShakeend = t.appearAnimGroup:CreateAnimation("Translation")
	appearShakeend:SetOffset(10, 0)
	appearShakeend:SetDuration(0.04)
	appearShakeend:SetOrder(5)
    t.appearAnimGroup:SetScript("OnFinished", function()
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", t.anchorBtn or self.frame, "TOP", 0, 0)
      -- Zet geen t.wasShown = nil hier, alleen bij fade!
    end)
  end
end

function TOTEM3D:UpdateTotems()
  self:CreateFrame()
  if self.mode == self.MODE_OFF then
    self.frame:Hide()
    for i = 1, 4 do self.models[i]:Hide(); self.arts[i]:Hide() end
    return
  end
  self.frame:Show()
  local artPaths = self.artPathsFunc(self.selectedArtSet or 1)
  for slot = 1, 4 do
    local haveTotem, totemName, startTime, duration, _ = GetTotemInfo(slot)
    local m = self.models[slot]
    local art = self.arts[slot]
    local wasVisible = art:IsShown()
    local btn = nil

    if self.mode == self.MODE_3D then
      if haveTotem and duration and duration > 0 and totemName and totemName ~= "" then
        btn = FindSnapButtonForTotem(totemName)
        if btn and self.modelPaths[slot] then
          if not m:IsShown() then
            m:SetModel(self.modelPaths[slot])
            m:SetCamDistanceScale(2.1)
            m:SetPosition(0, 0, -1.7)
            m:SetFacing(0)
            m:SetAlpha(1)
            m:Show()
          end
          m:ClearAllPoints()
          m:SetPoint("BOTTOM", btn, "TOP", 0, 0)
          if ShouldFadeTotem(slot) then
            m:SetAlpha(0.20)
          else
            m:SetAlpha(1)
          end
        else
          m:Hide()
        end
        art:Hide()
      else
        m:Hide()
        art:Hide()
      end

    elseif self.mode == self.MODE_ART then
      m:Hide()
      if haveTotem and duration and duration > 0 and totemName and totemName ~= "" then
        btn = FindSnapButtonForTotem(totemName)
        if btn then
          -- If a new totem appears while the old fade animation is still playing,
          -- stop the fade and reset art.wasShown so the appear animation replays
          if art.isFading then
            art.animGroup:Stop()
            art.isFading = nil
            art.wasShown = nil
            art:SetAlpha(1)
          end
          local artSet = artPaths[slot]
          local texW, texH = 161, 271
          local tgtW, tgtH = 56, 100
          local scale = math.min(tgtW/texW, tgtH/texH)
          local fitW = math.floor(texW * scale)
          local fitH = math.floor(texH * scale)
          art:SetTexture(artSet)
          art:SetSize(fitW, fitH)
          art:ClearAllPoints()
          if not art.wasShown then
            art:SetPoint("BOTTOM", btn, "TOP", 0, -70)
            art.anchorBtn = btn
          else
            art:SetPoint("BOTTOM", btn, "TOP", 0, 0)
            art.anchorBtn = btn
          end
          art:Show()
          if ShouldFadeTotem(slot) then
            art:SetAlpha(0.20)
          else
            art:SetAlpha(1)
          end
          -- Appear animatie bij nieuw verschijnen
          if not art.wasShown then
            art.appearAnimGroup:Play()
            art.wasShown = true
            art.isFading = nil
          end
        else
          art:Hide()
          art.wasShown = nil
          art.isFading = nil
        end
      else
        -- Fade/drop/shake anim eenmalig bij disappear
        if wasVisible and art.animGroup and not art.isFading then
          art.isFading = true
          art.animGroup:Play()
        end
        -- Geen Hide/reset hier; gebeurt pas in animGroup OnFinished
      end
    end
  end
end

function TOTEM3D:NextMode()
  self.mode = (self.mode + 1) % #self.modes
  if ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global then
    ExtendedUI_DB.profile.global.totem3DMode = self.mode
  end
  self:Show()
  self:StartTrackerLoop()
end

function TOTEM3D:GetEnabled()
  return self.mode ~= self.MODE_OFF
end
function TOTEM3D:SetEnabled(state)
  if state == nil then state = true end
  if type(state) == "number" then self.mode = state end
  if state == false or state == self.MODE_OFF then
    self.mode = self.MODE_OFF
    self:Hide()
    self:StopTrackerLoop()
    return
  end
  if not self.mode or self.mode == self.MODE_OFF then
    self.mode = self.MODE_3D
  end
  self:Show()
  self:StartTrackerLoop()
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
    if self.arts[i] then self.arts[i]:Hide() end
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
eventFrame:SetScript("OnEvent", function()
  if TOTEM3D:GetEnabled() then
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
      if ExtendedUI_DB.profile.global.totem3DMode then
        TOTEM3D.mode = ExtendedUI_DB.profile.global.totem3DMode
      else
        TOTEM3D.mode = TOTEM3D.MODE_3D
      end
      if ExtendedUI_DB.profile.global.totemArtSelectedSet then
        TOTEM3D.selectedArtSet = ExtendedUI_DB.profile.global.totemArtSelectedSet
      else
        TOTEM3D.selectedArtSet = 1
      end
      if TOTEM3D.mode ~= TOTEM3D.MODE_OFF then
        TOTEM3D:Show()
        TOTEM3D:StartTrackerLoop()
      else
        TOTEM3D:Hide()
        TOTEM3D:StopTrackerLoop()
      end
    end
  end
end)