-- DynamicTotemFlyout.lua

local slotArrows = {}
local totemList = {}
local flyout


if select(2, UnitClass("player")) ~= "SHAMAN" then return end
-- ========== Tooltipscan: welk element heeft een spell? ==========
local scanTip = CreateFrame("GameTooltip", "DTotemScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")
local function GetTotemElement(spellId)
  if not spellId then return nil end
  scanTip:ClearLines()
  scanTip:SetSpellByID(spellId)
  for i = 2, scanTip:NumLines() do
    local txt = _G["DTotemScanTooltipTextLeft"..i] and _G["DTotemScanTooltipTextLeft"..i]:GetText()
    if txt then
      local el = txt:match("(%w+) Totem")
      if el and (el == "Fire" or el == "Water" or el == "Earth" or el == "Air") then
        return el
      end
    end
  end
  return nil
end

-- ========== Dynamisch lijst generen van totems in spellbook ==========
local function BuildTotemList()
  totemList = { Fire={}, Water={}, Earth={}, Air={} }
  for tab=1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for idx=1, numSpells do
      local slot = offset + idx
      local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
      local typ, spellId = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      local icon = GetSpellTexture(slot, BOOKTYPE_SPELL)
      if spellId and name and (typ == "SPELL" or typ == "FUTURESPELL") then
        local element = GetTotemElement(spellId)
        if element then
          local found = false
          for _, info in ipairs(totemList[element]) do
            if info.spellId == spellId then found = true break end
          end
          if not found then
            table.insert(totemList[element], { spellId = spellId, name = name, icon = icon })
          end
        end
      end
    end
  end
end

-- ========== Actionbar namen ==========
local ActionBars = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarRightButton", "MultiBarLeftButton"
}

local function ScanActionButton(btn)
  if not btn then return end
  local actionId = btn.action or btn:GetID()
  if type(ActionButton_GetPagedID)=="function" then
    actionId = ActionButton_GetPagedID(btn) or actionId
  end
  local typ, spellId = GetActionInfo(actionId)
  if typ == "spell" and spellId then
    local element = GetTotemElement(spellId)
    if element then return spellId, element, actionId end
  end
  return nil
end

-- ========== Flyout Frame (boven barbutton) ==========
local function EnsureFlyout()
  if flyout then return flyout end
  flyout = CreateFrame("Frame", "DTotemFlyout", UIParent, "BackdropTemplate")
  flyout:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background" })
  flyout:SetBackdropColor(0,0,0,0.96)
  flyout:SetFrameStrata("FULLSCREEN_DIALOG")
  flyout:SetFrameLevel(20)
  flyout:SetSize(44,1)
  flyout:EnableMouse(true)
  flyout.buttons = {}

  flyout:SetScript("OnLeave", function()
    -- Flyout sluit vanzelf als je eraf gaat
    C_Timer.After(0.10, function()
      if not MouseIsOver(flyout) then
        flyout:Hide()
        -- Herstel arrows (maak ze weer 100% zichtbaar)
        for _, tab in pairs(slotArrows) do
          for _, arrow in pairs(tab) do
            if arrow then arrow:SetAlpha(1) end
          end
        end
      end
    end)
  end)
  flyout:Hide()
  return flyout
end

-- ========== Swappen: spell in actiebar zetten ==========
local function SwapSpellInActionButton(slotBtn, actionId, newSpell)
  local prevLock = GetCVar and GetCVar("lockActionBars")
  if prevLock and prevLock ~= "0" and SetCVar then SetCVar("lockActionBars", "0") end
  PickupSpell(newSpell)
  PlaceAction(actionId)
  ClearCursor()
  if prevLock and prevLock ~= "0" and SetCVar then SetCVar("lockActionBars", prevLock) end
end

-- ========== Flyout tonen, met alternatieven (bij pijltje-click) ==========
local function ShowTotemFlyoutAt(btn, curSpell, element, actionId)
  local choices = {}
  for _, info in ipairs(totemList[element]) do
    if info.spellId ~= curSpell then table.insert(choices, info) end
  end
  if #choices == 0 then
    if flyout then flyout:Hide() end
    return
  end
  local btnsize, gap = 38, 4
  local N = #choices
  local f = EnsureFlyout()
  f:ClearAllPoints()
  f:SetSize(btnsize+8, N*btnsize + (N-1)*gap + 10)
  f:SetPoint("BOTTOM", btn, "TOP", 0, 12)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(20)
  f:Show()

  -- Fade andere arrows uit tijdens flyout (optioneel visueel)
  for _, tab in pairs(slotArrows) do
    for _, arrow in pairs(tab) do
      if arrow then arrow:SetAlpha(0.15) end
    end
  end

  for i, info in ipairs(choices) do
    local b = f.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, f)
      b:SetSize(btnsize, btnsize)
      b:RegisterForClicks("AnyUp")
      b:EnableMouse(true)
      b:SetFrameStrata("FULLSCREEN_DIALOG")
      b:SetFrameLevel(f:GetFrameLevel() + 10)
      b.icon = b:CreateTexture(nil,"ARTWORK")
      b.icon:SetAllPoints(b)
      f.buttons[i] = b
    end
    b:Show()
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", f, "BOTTOM", 0, (i-1)*(btnsize+gap)+6)
    b.icon:SetTexture(info.icon)
    b.spellId = info.spellId
    b:SetFrameStrata("FULLSCREEN_DIALOG")
    b:SetFrameLevel(f:GetFrameLevel() + 10)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spellId)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      SwapSpellInActionButton(btn, actionId, info.spellId)
      f:Hide()
      -- Show arrows weer
      for _, tab in pairs(slotArrows) do
        for _, arrow in pairs(tab) do
          if arrow then arrow:SetAlpha(1) end
        end
      end
    end)
  end
  for i = N+1, #f.buttons do if f.buttons[i] then f.buttons[i]:Hide() end end
end

-- ========== Arrow per slot tonen/verbergen ==========
local function EnsureSlotArrow(prefix, idx, btn)
  slotArrows[prefix] = slotArrows[prefix] or {}
  if slotArrows[prefix][idx] and slotArrows[prefix][idx]._valid then return slotArrows[prefix][idx] end
  local arrow = CreateFrame("Button", nil, UIParent)
  arrow:SetSize(22, 22)
  arrow:SetFrameStrata("FULLSCREEN_DIALOG")
  arrow:SetFrameLevel(20)
  arrow:SetPoint("BOTTOM", btn, "TOP", 0, -3)
  arrow:SetToplevel(false)
  local tex = arrow:CreateTexture(nil, "ARTWORK", nil, 3)
  tex:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
  tex:SetVertexColor(1, 0.96, 0.20)
  tex:SetAllPoints()
  arrow:SetNormalTexture(tex)
  arrow._parentBtn = btn
  arrow._valid = true
  slotArrows[prefix][idx] = arrow

  arrow:SetScript("OnClick", function(self)
    local spellId, element, actionId = ScanActionButton(self._parentBtn)
    if spellId and element and actionId then
      ShowTotemFlyoutAt(self._parentBtn, spellId, element, actionId)
    end
  end)
  arrow:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
  arrow:SetScript("OnLeave", function(self) self:SetAlpha(1) end)
  return arrow
end

-- ========== Arrows (en flyouts) per slot updaten ==========

local function UpdateAllTotemArrows()
  for _, prefix in ipairs(ActionBars) do
    for i=1,12 do
      local btn = _G[prefix..i]
      if btn then
        local spellId, element, actionId = ScanActionButton(btn)
        local arrow = slotArrows[prefix] and slotArrows[prefix][i]
        if spellId and element and actionId then
          if not arrow then arrow = EnsureSlotArrow(prefix, i, btn) end
          arrow:ClearAllPoints()
          arrow:SetPoint("BOTTOM", btn, "TOP", 0, -3)
          arrow:Show()
          arrow:SetAlpha(1)
          arrow._valid = true
        elseif arrow then
          arrow:Hide()
          arrow._valid = false
        end
      end
    end
  end
end

local function CleanOldArrows()
  for prefix, tab in pairs(slotArrows) do
    for idx, arrow in pairs(tab) do
      if arrow and not arrow._valid then arrow:Hide() end
    end
  end
end

-- ========== Events die alles actueel houden ==========

local evt = CreateFrame("Frame")
evt:RegisterEvent("SPELLS_CHANGED")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
evt:RegisterEvent("ACTIONBAR_UPDATE_STATE")
evt:SetScript("OnEvent", function(self, event)
  BuildTotemList()
  UpdateAllTotemArrows()
  CleanOldArrows()
end)

if IsLoggedIn() then
  BuildTotemList()
  UpdateAllTotemArrows()
  CleanOldArrows()
end