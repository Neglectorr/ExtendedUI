local slotArrows = {}
local portList = {}
local flyout

-- Alleen bij Mage aan
if select(2, UnitClass("player")) ~= "MAGE" then return end

-- Spell herkenning (teleport/portal) op basis van spellnaam
local function IsMagePortalSpell(spellId)
  if not spellId then return false end
  local name = GetSpellInfo(spellId)
  if name and name:lower():find("portal") then return "Portal", name end
  if name and name:lower():find("teleport") then return "Teleport", name end
  return false
end

-- Lijst met ALLE portals/teleports uit je spellbook
local function BuildPortList()
  portList = {}
  for tab=1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for idx=1, numSpells do
      local slot = offset + idx
      local typ, spellId = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
      local icon = GetSpellTexture(slot, BOOKTYPE_SPELL)
      if spellId and name and (typ == "SPELL" or typ == "FUTURESPELL") then
        local portalType, trueName = IsMagePortalSpell(spellId)
        if portalType then
          local found = false
          for _, info in ipairs(portList) do
            if info.spellId == spellId then found = true break end
          end
          if not found then
            table.insert(portList, { spellId = spellId, name = trueName or name, icon = icon, portalType = portalType })
          end
        end
      end
    end
  end
end

local function SwapSpellInActionButton(slot, newSpell)
  local prevLock = GetCVar and GetCVar("lockActionBars")
  if prevLock and prevLock ~= "0" and SetCVar then SetCVar("lockActionBars", "0") end
  PickupSpell(newSpell)
  PlaceAction(slot)
  ClearCursor()
  if prevLock and prevLock ~= "0" and SetCVar then SetCVar("lockActionBars", prevLock) end
end

local function ShowMageFlyoutAt(btn, curSpell, portalType, slot)
  local choices = {}
  for _, info in ipairs(portList) do
    if info.spellId ~= curSpell and info.portalType == portalType then
      table.insert(choices, info)
    end
  end
  if #choices == 0 then if flyout then flyout:Hide() end return end

  if not flyout then
    flyout = CreateFrame("Frame", "MagePortFlyout", UIParent, "BackdropTemplate")
    flyout:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background" })
    flyout:SetBackdropColor(0,0,0,0.97)
    flyout:SetFrameStrata("FULLSCREEN_DIALOG")
    flyout:SetFrameLevel(21)
    flyout:SetSize(44, 1)
    flyout:EnableMouse(true)
    flyout.buttons = {}
    flyout:SetScript("OnLeave", function()
      C_Timer.After(0.10, function()
        if not MouseIsOver(flyout) then
          flyout:Hide()
          for _, tab in pairs(slotArrows) do
            for _, arrow in pairs(tab) do if arrow then arrow:SetAlpha(1) end end
          end
        end
      end)
    end)
  end

  local MARGIN, btnsize, gap = 6, 38, 4
  local N = #choices
  local totalHeight = N*btnsize + (N-1)*gap + 2*MARGIN

  flyout:ClearAllPoints()
  flyout:SetSize(btnsize+8, totalHeight)
  flyout:SetPoint("BOTTOM", btn, "TOP", 0, 12)
  flyout:SetFrameStrata("FULLSCREEN_DIALOG")
  flyout:SetFrameLevel(21)
  flyout:Show()
  for _, tab in pairs(slotArrows) do
    for _, arrow in pairs(tab) do if arrow then arrow:SetAlpha(0.15) end end
  end

  for i, info in ipairs(choices) do
    local b = flyout.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, flyout)
      b:SetSize(btnsize, btnsize)
      b:RegisterForClicks("AnyUp")
      b:EnableMouse(true)
      b:SetFrameStrata("FULLSCREEN_DIALOG")
      b:SetFrameLevel(flyout:GetFrameLevel() + 10)
      b.icon = b:CreateTexture(nil,"ARTWORK")
      b.icon:SetAllPoints(b)
      flyout.buttons[i] = b
    end
    b:Show()
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", flyout, "BOTTOM", 0, (i-1)*(btnsize+gap) + MARGIN)
    b.icon:SetTexture(info.icon)
    b.spellId = info.spellId
    b:SetFrameStrata("FULLSCREEN_DIALOG")
    b:SetFrameLevel(flyout:GetFrameLevel() + 10)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spellId)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      SwapSpellInActionButton(slot, info.spellId)
      flyout:Hide()
      for _, tab in pairs(slotArrows) do
        for _, arrow in pairs(tab) do if arrow then arrow:SetAlpha(1) end end
      end
    end)
  end
  for i = N+1, #flyout.buttons do if flyout.buttons[i] then flyout.buttons[i]:Hide() end end
end

local ActionBars = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarRightButton", "MultiBarLeftButton"
}

local function EnsureSlotArrow(prefix, idx, btn)
  slotArrows[prefix] = slotArrows[prefix] or {}
  if slotArrows[prefix][idx] and slotArrows[prefix][idx]._valid then return slotArrows[prefix][idx] end
  local arrow = CreateFrame("Button", nil, UIParent)
  arrow:SetSize(22, 22)
  arrow:SetFrameStrata("FULLSCREEN_DIALOG")
  arrow:SetFrameLevel(20)
  arrow:SetPoint("BOTTOM", btn, "TOP", 0, -3)
  local tex = arrow:CreateTexture(nil, "ARTWORK")
  tex:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
  tex:SetVertexColor(0.2, 0.65, 1) -- blauw-wit voor mage
  tex:SetAllPoints()
  arrow:SetNormalTexture(tex)
  arrow._parentBtn = btn
  arrow._valid = true
  slotArrows[prefix][idx] = arrow
  arrow:SetScript("OnClick", function(self)
    local slot = (ActionButton_GetPagedID and ActionButton_GetPagedID(btn)) or btn.action or btn:GetID()
    local typ, spellId = GetActionInfo(slot)
    local portalType, _ = IsMagePortalSpell(spellId)
    if typ == "spell" and portalType then
      ShowMageFlyoutAt(btn, spellId, portalType, slot)
    end
  end)
  arrow:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
  arrow:SetScript("OnLeave", function(self) self:SetAlpha(1) end)
  return arrow
end

local function UpdateAllMageArrows()
  for _, prefix in ipairs(ActionBars) do
    for i=1,12 do
      local btn = _G[prefix..i]
      if btn then
        local slot = (ActionButton_GetPagedID and ActionButton_GetPagedID(btn)) or btn.action or btn:GetID()
        local typ, spellId = GetActionInfo(slot)
        local portalType, _ = IsMagePortalSpell(spellId)
        if typ == "spell" and portalType then
          local arrow = slotArrows[prefix] and slotArrows[prefix][i]
          if not arrow then arrow = EnsureSlotArrow(prefix, i, btn) end
          arrow:ClearAllPoints()
          arrow:SetPoint("BOTTOM", btn, "TOP", 0, -3)
          arrow:Show()
          arrow:SetAlpha(1)
          arrow._valid = true
        elseif slotArrows[prefix] and slotArrows[prefix][i] then
          slotArrows[prefix][i]:Hide()
          slotArrows[prefix][i]._valid = false
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

local evt = CreateFrame("Frame")
evt:RegisterEvent("SPELLS_CHANGED")
evt:RegisterEvent("PLAYER_LOGIN")
evt:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
evt:RegisterEvent("ACTIONBAR_UPDATE_STATE")
evt:SetScript("OnEvent", function(self, event)
  BuildPortList()
  UpdateAllMageArrows()
  CleanOldArrows()
end)

if IsLoggedIn() then
  BuildPortList()
  UpdateAllMageArrows()
  CleanOldArrows()
end