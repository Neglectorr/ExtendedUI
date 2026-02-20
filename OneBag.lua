local EUI = ExtendedUI
local OB = {}
EUI.OneBag = OB

local ORIG_ToggleAllBags
local ORIG_ToggleBackpack
local ORIG_ToggleBag

local ORIG_OpenAllBags
local ORIG_OpenBackpack
local ORIG_OpenBag
local ORIG_CloseAllBags

-- ===== Tuning =====
local BORDER_THICKNESS = 2
local BORDER_ALPHA = 1.0
local SLOT_BG_ALPHA = 0.35
local ICON_INSET = 2
-- ==================

local function EnsureDB()
  ExtendedUI_DB = ExtendedUI_DB or {}
  ExtendedUI_DB.profile = ExtendedUI_DB.profile or {}
  ExtendedUI_DB.profile.global = ExtendedUI_DB.profile.global or {}
  local g = ExtendedUI_DB.profile.global
  if g.oneBagEnabled == nil then g.oneBagEnabled = true end
  g.oneBagFrame = g.oneBagFrame or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
end

local function Enabled()
  return ExtendedUI_DB
    and ExtendedUI_DB.profile
    and ExtendedUI_DB.profile.global
    and ExtendedUI_DB.profile.global.oneBagEnabled
end

local function CanMove()
  return not (InCombatLockdown and InCombatLockdown())
end

local function BagMinMax()
  local max = (type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS) or 4
  return 0, max
end

local function GetNumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function GetItemLink(bag, slot)
  if C_Container and C_Container.GetContainerItemLink then
    return C_Container.GetContainerItemLink(bag, slot)
  end
  if GetContainerItemLink then
    return GetContainerItemLink(bag, slot)
  end
  return nil
end

-- returns: icon, count, link, quality
local function GetContainerInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil, nil, nil, nil end
    return info.iconFileID, info.stackCount, info.hyperlink, info.quality
  end
  if GetContainerItemInfo then
    local icon, count, _, quality, _, _, link2 = GetContainerItemInfo(bag, slot)
    return icon, count, link2, quality
  end
  return nil, nil, nil, nil
end

local function PlaceButtonInGrid(f, b, idx)
  local col = (idx - 1) % f.cols
  local row = math.floor((idx - 1) / f.cols)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + col * (f.slotSize + f.padding), -40 - row * (f.slotSize + f.padding))
  b:SetSize(f.slotSize, f.slotSize)
end

local function GetBlizzardItemButtonPrototype()
  local proto = _G["ContainerFrame1Item1"]
  if not proto then return nil end

  local function SafeScript(name)
    local fn = proto.GetScript and proto:GetScript(name)
    if type(fn) == "function" then return fn end
    return nil
  end

  return {
    OnClick = SafeScript("OnClick"),
    OnDragStart = SafeScript("OnDragStart"),
    OnReceiveDrag = SafeScript("OnReceiveDrag"),
  }
end

-- Money formatting
local function FormatMoney(copper)
  copper = tonumber(copper) or 0
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = math.floor(copper % 100)
  if g > 0 then
    return string.format("%dg %ds %dc", g, s, c)
  elseif s > 0 then
    return string.format("%ds %dc", s, c)
  else
    return string.format("%dc", c)
  end
end

function OB:UpdateMoney()
  local f = self.frame
  if not f or not f.moneyText then return end
  local money = GetMoney and GetMoney() or 0
  f.moneyText:SetText(FormatMoney(money))
end

-- Sounds
local function PlayBagSound(opening)
  if not PlaySound then return end
  if opening then
    local ok = pcall(function() PlaySound("igBackPackOpen") end)
    if not ok then pcall(function() PlaySound(856) end) end
  else
    local ok = pcall(function() PlaySound("igBackPackClose") end)
    if not ok then pcall(function() PlaySound(857) end) end
  end
end

local function GetQualityColor(quality)
  local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if col then return col.r, col.g, col.b end
  if quality == 0 then return 0.62, 0.62, 0.62 end
  if quality == 1 then return 1, 1, 1 end
  if quality == 2 then return 0.12, 1, 0 end
  if quality == 3 then return 0, 0.44, 0.87 end
  if quality == 4 then return 0.64, 0.21, 0.93 end
  if quality == 5 then return 1, 0.5, 0 end
  return 1, 1, 1
end

local function EnsureSlotChrome(b)
  if b._euiChrome then return end
  b._euiChrome = true

  local bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
  b.slotBg = bg
  bg:SetAllPoints(b)
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bg:SetVertexColor(0, 0, 0, SLOT_BG_ALPHA)

  b.rarityBorder = {}
  local function mkBar()
    local t = b:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    t:SetAlpha(BORDER_ALPHA)
    t:Hide()
    return t
  end
  local top = mkBar()
  top:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
  top:SetHeight(BORDER_THICKNESS)
  local bottom = mkBar()
  bottom:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(BORDER_THICKNESS)
  local left = mkBar()
  left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
  left:SetWidth(BORDER_THICKNESS)
  local right = mkBar()
  right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(BORDER_THICKNESS)
  b.rarityBorder.top = top
  b.rarityBorder.bottom = bottom
  b.rarityBorder.left = left
  b.rarityBorder.right = right
end

local function ApplyRarityBorder(btn, quality)
  if not (btn and btn.rarityBorder) then return end
  if quality == nil then
    for _, t in pairs(btn.rarityBorder) do t:Hide() end
    return
  end
  local r, g, b = GetQualityColor(quality)
  for _, t in pairs(btn.rarityBorder) do
    t:SetVertexColor(r, g, b, 1)
    t:Show()
  end
end

local function CloseVanillaBags()
  if CloseAllBags then CloseAllBags() return end
  for i = 1, 13 do
    local cf = _G["ContainerFrame" .. i]
    if cf and cf.Hide then cf:Hide() end
  end
end

-------------- FRAME LOGIC MET ZOEKVELD --------------

function OB:EnsureFrame()
  if self.frame then return end

  local f = CreateFrame("Frame", "ExtendedUIOneBagFrame", UIParent, "BackdropTemplate")
  self.frame = f
  f:SetSize(480, 420)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetFrameLevel(4)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.15, 0.15, 0.15, 0.92)

  if UISpecialFrames then
    local found = false
    for i = 1, #UISpecialFrames do
      if UISpecialFrames[i] == "ExtendedUIOneBagFrame" then found = true break end
    end
    if not found then table.insert(UISpecialFrames, "ExtendedUIOneBagFrame") end
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 14, -12)
  local playerName = UnitName and UnitName("player") or "Character"
  title:SetText(string.format("%s's bags", playerName))

  -- Searchbox (nieuw!)
  local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  searchBox:SetSize(140,20)
  searchBox:SetPoint("TOPRIGHT", -160, -12)
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(32)
  searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); OB.searchText = ""; OB:Update() end)
  searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  searchBox:SetScript("OnTextChanged", function(self)
    OB.searchText = self:GetText() or ""
    OB:Update()
  end)
  searchBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0,0) end)
  f._searchBox = searchBox
  OB.searchText = ""

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")

  local bagsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  bagsBtn:SetSize(60, 24)
  bagsBtn:SetText("Bags")
  bagsBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
  bagsBtn:SetScript("OnClick", function()
    ExtendedUI_DB.profile.global.oneBagEnabled = false
    OB:Hide()
    C_Timer.After(0.1, function()
      if OpenBackpack then OpenBackpack() end
      for i = 1, 4 do
        if OpenBag then OpenBag(i) end
      end
      local monitor
      monitor = C_Timer.NewTicker(0.2, function()
        local allClosed = true
        for i = 1, 5 do
          local cf = _G["ContainerFrame"..i]
          if cf and cf:IsShown() then
            allClosed = false
            break
          end
        end
        if allClosed then
          ExtendedUI_DB.profile.global.oneBagEnabled = true
          monitor:Cancel() -- stop polling
        end
      end)
    end)
  end)
  close:SetPoint("TOPRIGHT", -6, -6)

  local money = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.moneyText = money
  money:SetPoint("BOTTOMRIGHT", -14, 12)
  money:SetTextColor(1, 0.82, 0.1)
  money:SetText("0c")

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    if not CanMove() then return end
    if not IsShiftKeyDown() then return end
    f:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    EnsureDB()
    local db = ExtendedUI_DB.profile.global.oneBagFrame
    local point, _, relPoint, x, y = f:GetPoint(1)
    db.point = point or "CENTER"
    db.relPoint = relPoint or "CENTER"
    db.x = x or 0
    db.y = y or 0
  end)

  f.slotSize = 32
  f.padding = 6
  f.cols = 12
  f.slots = {}

  f._blizzProto = GetBlizzardItemButtonPrototype()

  f:Hide()
  f:SetScript("OnShow", function(self)
    OB:RestorePosition()
    OB:Layout()
    OB:Update()
    OB:UpdateMoney()
    PlayBagSound(true)
    self:SetScript("OnUpdate", OB.CheckProtectedSpellAndEscape)
  end)
  f:SetScript("OnHide", function(self)
    PlayBagSound(false)
    self:SetScript("OnUpdate", nil)
  end)
end

function OB:RestorePosition()
  EnsureDB()
  local db = ExtendedUI_DB.profile.global.oneBagFrame
  self.frame:ClearAllPoints()
  self.frame:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
end

function OB:Show()
  self:EnsureFrame()
  if not self.frame:IsShown() then self.frame:Show() end
end

function OB:Hide()
  if self.frame and self.frame:IsShown() then self.frame:Hide() end
end

function OB:Toggle()
  self:EnsureFrame()
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function OB:_AttachBlizzardHandlers(button)
  local f = self.frame
  if not (f and f._blizzProto and (f._blizzProto.OnClick or f._blizzProto.OnDragStart or f._blizzProto.OnReceiveDrag)) then
    return false
  end

  if not button._euiBagParent then
    button._euiBagParent = CreateFrame("Frame", nil, button)
  end

  button.GetParent = function(selfBtn)
    return selfBtn._euiBagParent
  end

  if f._blizzProto.OnClick then button:SetScript("OnClick", f._blizzProto.OnClick) end
  if f._blizzProto.OnDragStart then button:SetScript("OnDragStart", f._blizzProto.OnDragStart) end
  if f._blizzProto.OnReceiveDrag then button:SetScript("OnReceiveDrag", f._blizzProto.OnReceiveDrag) end

  return true
end

function OB:Layout()
  local f = self.frame
  if not f then return end

  local bagMin, bagMax = BagMinMax()
  local idx = 0

  for bag = bagMin, bagMax do
    local n = GetNumSlots(bag)
    for slot = 1, n do
      idx = idx + 1
      local b = f.slots[idx]
      if not b then
        b = CreateFrame("Button", nil, f)
        f.slots[idx] = b

        EnsureSlotChrome(b)

        b.icon = b:CreateTexture(nil, "ARTWORK", nil, 0)
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", ICON_INSET, -ICON_INSET)
        b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)

        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetPoint("TOPLEFT", b, "TOPLEFT", ICON_INSET, -ICON_INSET)
        b.hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
        b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        b.hl:SetBlendMode("ADD")

        b:SetScript("OnEnter", function(selfBtn)
          if selfBtn.bag and selfBtn.slot then
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(selfBtn.bag, selfBtn.slot)
            GameTooltip:Show()
          end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)

        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")

        OB:_AttachBlizzardHandlers(b)
      end

      b.bag = bag
      b.slot = slot

      b:SetID(slot)
      if b._euiBagParent and b._euiBagParent.SetID then
        b._euiBagParent:SetID(bag)
      elseif b._euiBagParent then
        b._euiBagParent.id = bag
        b._euiBagParent.GetID = function(self) return self.id end
      end

      PlaceButtonInGrid(f, b, idx)
      b:Show()
    end
  end

  for i = idx + 1, #f.slots do
    f.slots[i]:Hide()
  end
end

function OB:Update()
  local f = self.frame
  if not f or not f:IsShown() then return end
  local search = string.lower(OB.searchText or "")

  for i = 1, #f.slots do
    local b = f.slots[i]
    if b and b:IsShown() then
      local icon, count, link, quality = GetContainerInfo(b.bag, b.slot)
      if not link then link = GetItemLink(b.bag, b.slot) end

      local name
      if link then name = GetItemInfo(link) end

      b.icon:SetTexture(icon)
      if count and count > 1 then b.count:SetText(count) else b.count:SetText("") end

      ApplyRarityBorder(b, quality)

      -- SEARCH/FILTER ALPHA
      if icon then
        local found = (not search or search == "") or (name and string.find(string.lower(name), search, 1, true))
        b:SetAlpha(found and 1 or 0.23)
      else
        b:SetAlpha(1)
      end
    end
  end
end

--------------------- OpenBag Enable (B/Shift+B/TOGGLE) ---------------------

function EUI:OneBag_SetEnabled(enabled)
  EnsureDB()
  ExtendedUI_DB.profile.global.oneBagEnabled = enabled and true or false

  if not ORIG_ToggleAllBags and ToggleAllBags then
    ORIG_ToggleAllBags = ToggleAllBags
    ToggleAllBags = function()
      EnsureDB()
      if not Enabled() then return ORIG_ToggleAllBags() end
      if IsShiftKeyDown and IsShiftKeyDown() then return ORIG_ToggleAllBags() end
      OB:Toggle()
    end
  end

  if not ORIG_ToggleBackpack and ToggleBackpack then
    ORIG_ToggleBackpack = ToggleBackpack
    ToggleBackpack = function()
      EnsureDB()
      if not Enabled() then return ORIG_ToggleBackpack() end
      OB:Toggle()
    end
  end

  if not ORIG_ToggleBag and ToggleBag then
    ORIG_ToggleBag = ToggleBag
    ToggleBag = function(_bagId)
      EnsureDB()
      if not Enabled() then return ORIG_ToggleBag(_bagId) end
      OB:Toggle()
    end
  end

  if not ORIG_OpenAllBags and OpenAllBags then
    ORIG_OpenAllBags = OpenAllBags
    OpenAllBags = function(...)
      EnsureDB()
      if not Enabled() then return ORIG_OpenAllBags(...) end
      OB:Show()
    end
  end

  if not ORIG_OpenBackpack and OpenBackpack then
    ORIG_OpenBackpack = OpenBackpack
    OpenBackpack = function(...)
      EnsureDB()
      if not Enabled() then return ORIG_OpenBackpack(...) end
      OB:Show()
    end
  end

  if not ORIG_OpenBag and OpenBag then
    ORIG_OpenBag = OpenBag
    OpenBag = function(_bagId, ...)
      EnsureDB()
      if not Enabled() then return ORIG_OpenBag(_bagId, ...) end
      OB:Show()
    end
  end

  if not ORIG_CloseAllBags and CloseAllBags then
    ORIG_CloseAllBags = CloseAllBags
    CloseAllBags = function(...)
      EnsureDB()
      if not Enabled() then return ORIG_CloseAllBags(...) end
      OB:Hide()
    end
  end

  if not enabled and OB.frame and OB.frame:IsShown() then
    OB.frame:Hide()
  end
end

-- ----------- TRADESKILL-PROTECTED CURSOR SPELL ESCAPE -----------
local SPELLS_TRIGGER_ORIG_BAGS = {
  [31252] = true, -- Prospecting
  [13262] = true, -- Disenchant
  [51005] = true, -- Milling (Wrath+)
}
local protectedSpellsByName = {}
do
  for spellId in pairs(SPELLS_TRIGGER_ORIG_BAGS) do
    local n = GetSpellInfo and GetSpellInfo(spellId)
    if n then protectedSpellsByName[n] = true end
  end
end

function OB.CheckProtectedSpellAndEscape(self, elapsed)
  self._euitmp_elapsed = (self._euitmp_elapsed or 0) + (elapsed or 0)
  if self._euitmp_elapsed < 0.2 then return end
  self._euitmp_elapsed = 0
  if not OB.frame or not OB.frame:IsShown() then return end
  if not (GetCursorInfo) then return end
  local kind, spellName, spellId = GetCursorInfo()
  if kind == "spell" and (protectedSpellsByName[spellName] or SPELLS_TRIGGER_ORIG_BAGS[spellId]) then
    OB:Hide()
    if OpenAllBags then OpenAllBags() end
  end
end
-- ---------------------------------------------------------------

local vendor = CreateFrame("Frame")
vendor:RegisterEvent("MERCHANT_SHOW")
vendor:SetScript("OnEvent", function()
  EnsureDB()
  if not Enabled() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  CloseVanillaBags()
  OB:Show()
end)

local evt = CreateFrame("Frame")
evt:RegisterEvent("BAG_UPDATE")
evt:RegisterEvent("BAG_UPDATE_DELAYED")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("PLAYER_MONEY")
evt:RegisterEvent("SEND_MAIL_MONEY_CHANGED")
evt:RegisterEvent("SEND_MAIL_COD_CHANGED")
evt:RegisterEvent("TRADE_MONEY_CHANGED")
evt:RegisterEvent("GET_ITEM_INFO_RECEIVED")
evt:SetScript("OnEvent", function(_, event)
  if OB.frame and OB.frame:IsShown() then
    if event == "PLAYER_MONEY" or event == "SEND_MAIL_MONEY_CHANGED" or event == "SEND_MAIL_COD_CHANGED" or event == "TRADE_MONEY_CHANGED" then
      OB:UpdateMoney()
    else
      OB:Layout()
      OB:Update()
      OB:UpdateMoney()
    end
  end
end)

-- >>> Enable direct bij laden zodat 'B' en 'Shift+B' werken <<<
EUI:OneBag_SetEnabled(true)