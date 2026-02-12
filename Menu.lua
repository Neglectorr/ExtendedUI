EUI_Menu = {}
local M = EUI_Menu

local function EnsureDB()
  if not (ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global) then return end
  local g = ExtendedUI_DB.profile.global
  if g.oneBagEnabled == nil then g.oneBagEnabled = false end
  if g.lootToastEnabled == nil then g.lootToastEnabled = false end
  g.lootToast = g.lootToast or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
end

local function MakeCheck(parent, x, y, text)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", x, y)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  t:SetText(text)
  return cb, t
end

local function MakeButton(parent, x, y, w, h, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

M.submenus = {}

function M.RegisterSubMenuFrame(frame)
  table.insert(M.submenus, frame)
end

function M.CloseAll()
  for _, subframe in ipairs(M.submenus) do
    if subframe and subframe:IsShown() then subframe:Hide() end
  end
  if M.hub and M.hub:IsShown() then
    M.hub:Hide()
  end
end

function M.HideAllSubMenus()
  for _, subframe in ipairs(M.submenus) do
    if subframe and subframe:IsShown() then subframe:Hide() end
  end
end

function M.EnsureHub()
  if M.hub then return end

  local w = CreateFrame("Frame", "ExtendedUIHubFrame", UIParent, "BackdropTemplate")
  M.hub = w
  w:SetSize(340, 256)
  w:SetPoint("CENTER")
  w:SetFrameStrata("DIALOG")
  w:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  w:SetBackdropColor(0, 0, 0, 0.90)

  w:EnableMouse(true)
  w:SetMovable(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function() if not InCombatLockdown() then w:StartMoving() end end)
  w:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)

  local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("ExtendedUI")

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() M.CloseAll() end)

  MakeButton(w, 18, -54, 300, 26, "Actionbar Effects", function()
    M.OpenConfigSubMenu()
  end)
  MakeButton(w, 18, -92, 300, 26, "OneBag", function()
    M.OpenOneBagSubMenu()
  end)
  MakeButton(w, 18, -130, 300, 26, "Buff Tracker", function()
    M.OpenBuffTrackerSubMenu()
  end)
  MakeButton(w, 18, -168, 300, 26, "Sound Tweaks", function()
    M.OpenSoundTweaksSubMenu()
  end)

  -- Totem Tracker knop ALTIJD voor SHAMAN, ongeacht TOTEM3D presence
  local function IsPlayerShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
  end

  -- Voeg de knop toe indien shaman
  if IsPlayerShaman() then
    local totemBtn = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    totemBtn:SetPoint("TOPLEFT", 18, -206)
    totemBtn:SetSize(300, 26)
    totemBtn:SetText("Toggle Totem Tracker")

    totemBtn:SetScript("OnClick", function()
    if TOTEM3D then
        TOTEM3D:SetEnabled(not TOTEM3D.enabled)
        if TOTEM3D.enabled then
            totemBtn:SetText("Toggle Totem Tracker (aan)")
        else
            totemBtn:SetText("Toggle Totem Tracker")
        end
    else
        print("TotemTracker module niet geladen. Voeg TotemTracker.lua toe aan je .toc, vóór Menu.lua!")
		end
	end)
    if TOTEM3D and TOTEM3D.enabled then
		totemBtn:SetText("Toggle Totem Tracker (aan)")
	end
  end

  w:Hide()
end

function M.EnsureOneBagSettings()
  if M.onebag then return end

  local w = CreateFrame("Frame", "ExtendedUIOneBagSettingsFrame", UIParent, "BackdropTemplate")
  M.onebag = w
  M.RegisterSubMenuFrame(w)
  w:SetSize(520, 240)
  w:SetPoint("CENTER")
  w:SetFrameStrata("DIALOG")
  w:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  w:SetBackdropColor(0, 0, 0, 0.90)

  w:EnableMouse(true)
  w:SetMovable(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function() if not InCombatLockdown() then w:StartMoving() end end)
  w:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)

  local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("ExtendedUI - OneBag")

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function()
    w:Hide()
    if M.hub then M.hub:Show() end
  end)

  w.enableCB, _ = MakeCheck(w, 18, -50, "Enable OneBag (B/backpack uses OneBag; Shift+B keeps vanilla)")
  w.toastCB, _ = MakeCheck(w, 18, -80, "Enable Loot Toast")

  local hint = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 18, -120)
  hint:SetText("Loot Toast position placeholder is shown while this window is open (and toast enabled).\nDrag it to set position.")

  w:SetScript("OnShow", function()
    EnsureDB()
    local g = ExtendedUI_DB.profile.global
    w.enableCB:SetChecked(g.oneBagEnabled and true or false)
    w.toastCB:SetChecked(g.lootToastEnabled and true or false)

    if ExtendedUI and ExtendedUI.UpdateLootToastAnchor then
      ExtendedUI:UpdateLootToastAnchor(true)
    end
  end)

  w:SetScript("OnHide", function()
    if ExtendedUI and ExtendedUI.UpdateLootToastAnchor then
      ExtendedUI:UpdateLootToastAnchor(false)
    end
  end)

  w.enableCB:SetScript("OnClick", function(self)
    EnsureDB()
    ExtendedUI_DB.profile.global.oneBagEnabled = self:GetChecked() and true or false
    if ExtendedUI and ExtendedUI.OneBag_SetEnabled then
      ExtendedUI:OneBag_SetEnabled(ExtendedUI_DB.profile.global.oneBagEnabled)
    end
  end)

  w.toastCB:SetScript("OnClick", function(self)
    EnsureDB()
    ExtendedUI_DB.profile.global.lootToastEnabled = self:GetChecked() and true or false
    if ExtendedUI and ExtendedUI.UpdateLootToastAnchor then
      ExtendedUI:UpdateLootToastAnchor(true)
    end
  end)
  w:Hide()
end

function M.EnsureConfigMenu()
  if M.config then return end
  if not EUI_Config then return end
  EUI_Config.Toggle()
  local w = _G["ExtendedUIConfigFrame"]
  if w then
    M.config = w
    M.RegisterSubMenuFrame(w)
    if not w._menuCloseHook then
      local closeBtn = w:GetChildren()
      for i = 1, w:GetNumChildren() do
        local child = select(i, w:GetChildren())
        if child and child:GetObjectType() == "Button" and child:IsObjectType("Button") then
          local name = child:GetName() or ""
          if name:find("CloseButton") or name == "" then
            child:SetScript("OnClick", function()
              w:Hide()
              if M.hub then M.hub:Show() end
            end)
            w._menuCloseHook = true
            break
          end
        end
      end
    end
    w:Hide()
  end
end

function M.EnsureBuffTrackerMenu()
  if not EUI_BuffTracker then return end
  if not EUI_BuffTracker.menu then EUI_BuffTracker:EnsureConfigMenu() end
  if EUI_BuffTracker.menu then M.RegisterSubMenuFrame(EUI_BuffTracker.menu) end
end

function M.OpenOneBagSubMenu()
  M.EnsureOneBagSettings()
  M.HideAllSubMenus()
  if M.hub and M.hub:IsShown() then M.hub:Hide() end
  if M.onebag then M.onebag:Show() end
end
function M.OpenSoundTweaksSubMenu()
  M.HideAllSubMenus()
  if M.hub and M.hub:IsShown() then M.hub:Hide() end
  if EUI_SoundTweaks then
    EUI_SoundTweaks:EnsureConfigMenu()
    if EUI_SoundTweaks.menu then EUI_SoundTweaks.menu:Show() end
  end
end
function M.OpenConfigSubMenu()
  M.EnsureConfigMenu()
  M.HideAllSubMenus()
  if M.hub and M.hub:IsShown() then M.hub:Hide() end
  if M.config then M.config:Show() end
end

function M.OpenBuffTrackerSubMenu()
  M.EnsureBuffTrackerMenu()
  M.HideAllSubMenus()
  if M.hub and M.hub:IsShown() then M.hub:Hide() end
  if EUI_BuffTracker and EUI_BuffTracker.menu then EUI_BuffTracker.menu:Show() end
end

function M.ToggleHub()
  M.EnsureHub()
  M.HideAllSubMenus()
  if M.hub:IsShown() then
    M.hub:Hide()
  else
    M.hub:Show()
  end
end