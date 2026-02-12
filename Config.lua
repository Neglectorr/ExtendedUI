EUI_Config = {}
local C = EUI_Config

local BagItems = { list = {}, byId = {} }
local function ScanBags()
  BagItems.list = {}
  BagItems.byId = {}
  local seen = {}
  if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink then
    for bag = 0, 4 do
      local slots = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, slots do
        local link = C_Container.GetContainerItemLink(bag, slot)
        if link then
          local itemId = tonumber(string.match(link, "item:(%d+):"))
          if itemId and not seen[itemId] then
            seen[itemId] = true
            local name = GetItemInfo(itemId) or ("item:" .. itemId)
            local count = (GetItemCount and GetItemCount(itemId)) or 0
            table.insert(BagItems.list, { id = itemId, name = name, count = count })
            BagItems.byId[itemId] = true
          end
        end
      end
    end
  elseif GetContainerNumSlots and GetContainerItemLink then
    for bag = 0, 4 do
      local slots = GetContainerNumSlots(bag) or 0
      for slot = 1, slots do
        local link = GetContainerItemLink(bag, slot)
        if link then
          local itemId = tonumber(string.match(link, "item:(%d+):"))
          if itemId and not seen[itemId] then
            seen[itemId] = true
            local name = GetItemInfo(itemId) or ("item:" .. itemId)
            local count = (GetItemCount and GetItemCount(itemId)) or 0
            table.insert(BagItems.list, { id = itemId, name = name, count = count })
            BagItems.byId[itemId] = true
          end
        end
      end
    end
  else
    return
  end
  table.sort(BagItems.list, function(a, b) return (a.name or "") < (b.name or "") end)
end

local function EnsureRule(p, barId, slot, idx)
  return p.bars[barId][slot].rules[idx]
end

local function ColorOptions()
  return {
    { key="GOLD", text="Gold" },
    { key="RED", text="Red" },
    { key="GREEN", text="Green" },
    { key="BLUE", text="Blue" },
    { key="YELLOW", text="Yellow" },
    { key="ORANGE", text="Orange" },
    { key="PURPLE", text="Purple" },
    { key="CYAN", text="Cyan" },
    { key="WHITE", text="White" },
  }
end

local function ColorKeyToText(key)
  local map = {
    GOLD="Gold", RED="Red", GREEN="Green", BLUE="Blue",
    YELLOW="Yellow", ORANGE="Orange", PURPLE="Purple", CYAN="Cyan", WHITE="White",
  }
  return map[key] or "Gold"
end

local function TriggerOptions()
  return {
    { key = "NONE", text = "None" },
    { key = "THREAT_AT_LEAST", text = "Threat >= X" },
    { key = "TARGET_HP_BELOW", text = "Target HP% < X" },
    { key = "ITEM_COUNT_BELOW", text = "Item count < X" },
    { key = "MISSING_BUFF", text = "Missing buff (player/target)" },
    { key = "MISSING_DEBUFF_TARGET", text = "Target missing debuff" },
    { key = "TOTEM_SLOT_MISSING", text = "Totem Slot Missing (shaman)" },
  }
end

local TotemSlotLookup = {
  { num = 1, txt = "Fire (slot 1)" },
  { num = 2, txt = "Earth (slot 2)" },
  { num = 3, txt = "Water (slot 3)" },
  { num = 4, txt = "Air (slot 4)" }
}
local function TotemSlotNumToText(slot)
  slot = tonumber(slot)
  for i,v in ipairs(TotemSlotLookup) do
    if v.num == slot then return v.txt end
  end
  return tostring(slot or "?")
end

local function EffectOptionsForLane(lane)
  if lane == "A" then
    return {
      { key = "NONE", text = "None" },
      { key = "GLOW_BORDER", text = "BorderGlow" },
      { key = "AUTOCAST_RINGS", text = "Rotating" },
      { key = "AUTOCAST_SPARKLES", text = "Sparkles" },
    }
  elseif lane == "B" then
    return {
      { key = "NONE", text = "None" },
      { key = "FLASH", text = "Flash" },
    }
  elseif lane == "C" then
    return {
      { key = "NONE", text = "None" },
      { key = "ICON_TINT", text = "Icon dim" },
    }
  end
  return { { key = "NONE", text = "None" } }
end

local function EnsureWindow()
  if C.win then return end

  local w = CreateFrame("Frame", "ExtendedUIConfigFrame", UIParent, "BackdropTemplate")
  C.win = w
  w:SetSize(800, 600)
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
  title:SetText("ExtendedUI - Config")

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  C.state = C.state or { barId = 1, slot = 1 }

  local function Label(parent, text, x, y, template)
    local l = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    l:SetPoint("TOPLEFT", x, y)
    l:SetText(text)
    return l
  end

  local function MakeDropDown(parent, x, y, width)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x - 16, y)
    UIDropDownMenu_SetWidth(dd, width or 160)
    return dd
  end

  local function MakeEdit(parent, x, y, wdt)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(wdt or 160, 20)
    e:SetPoint("TOPLEFT", x, y)
    e:SetAutoFocus(false)
    return e
  end

  local function MakeSmallLabel(parent, anchor, text)
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    l:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    l:SetText(text)
    return l
  end

  local function ShowPair(control, label, show)
    if control then control:SetShown(show) end
    if label then label:SetShown(show) end
  end

  local function GetCurrentRule(ruleIndex)
    local p = ExtendedUI_DB.profile
    local barId, slot = C.state.barId, C.state.slot
    return p.bars[barId][slot].rules[ruleIndex]
  end

  Label(w, "Bar", 18, -46)
  C.barDD = MakeDropDown(w, 18, -64, 70)

  Label(w, "Slot", 140, -46)
  C.slotDD = MakeDropDown(w, 140, -64, 70)

  C.enabledCB = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
  C.enabledCB:SetPoint("TOPLEFT", 260, -62)
  local enabledText = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  enabledText:SetPoint("LEFT", C.enabledCB, "RIGHT", 4, 0)
  enabledText:SetText("Enabled")

  local refreshItems = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  refreshItems:SetSize(120, 22)
  refreshItems:SetPoint("TOPLEFT", 650, -60)
  refreshItems:SetText("Refresh items")
  refreshItems:SetScript("OnClick", function()
    ScanBags()
    if C.Refresh then C.Refresh() end
  end)

  local resetSlot = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
  resetSlot:SetSize(120, 22)
  resetSlot:SetPoint("LEFT", refreshItems, "RIGHT", -260, 0)
  resetSlot:SetText("Reset slot")
  resetSlot:SetScript("OnClick", function()
    local p = ExtendedUI_DB.profile
    local barId, slot = C.state.barId, C.state.slot

    p.bars[barId][slot].rules = {}
    for r = 1, ExtendedUI.RULES_PER_SLOT do
      if ExtendedUI and ExtendedUI.DefaultRule then
        p.bars[barId][slot].rules[r] = ExtendedUI:DefaultRule()
      else
        p.bars[barId][slot].rules[r] = {
          enabled = false,
          trigger = "NONE",
          params = { invert = false },
          effect = "NONE",
          effectParams = { dim50 = false, static = false, color = "GOLD" },
          debugForceOn = false,
        }
      end
    end

    if C.Refresh then C.Refresh() end
    if ExtendedUI and ExtendedUI.ApplySlot then ExtendedUI:ApplySlot(barId, slot) end
  end)

  UIDropDownMenu_Initialize(C.barDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    for barId = ExtendedUI.BAR_MIN, ExtendedUI.BAR_MAX do
      info.text = tostring(barId)
      info.checked = (C.state.barId == barId)
      info.func = function()
        C.state.barId = barId
        UIDropDownMenu_SetText(C.barDD, tostring(barId))
        if C.Refresh then C.Refresh() end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetText(C.barDD, tostring(C.state.barId))

  UIDropDownMenu_Initialize(C.slotDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    for i = 1, ExtendedUI.SLOTS_PER_BAR do
      info.text = tostring(i)
      info.checked = (C.state.slot == i)
      info.func = function()
        C.state.slot = i
        UIDropDownMenu_SetText(C.slotDD, tostring(i))
        if C.Refresh then C.Refresh() end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetText(C.slotDD, tostring(C.state.slot))

  C.rulesUI = {}

  local function CreateRuleBlock(idx, topY)
    local box = CreateFrame("Frame", nil, w, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 16, topY)
    box:SetSize(768, 160)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    box:SetBackdropColor(1, 1, 1, 0.04)

    local head = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 10, -8)
    head:SetText(("Rule %d (Lane %s)"):format(idx, ExtendedUI.LANE[idx]))

    local enabled = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 10, -32)
    local enabledT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledT:SetPoint("LEFT", enabled, "RIGHT", 4, 0)
    enabledT:SetText("Enabled")

    local force = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    force:SetPoint("LEFT", enabled, "RIGHT", 90, 0)
    local forceT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    forceT:SetPoint("LEFT", force, "RIGHT", 4, 0)
    forceT:SetText("Test: Force On")

    local triggerLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerLabel:SetPoint("TOPLEFT", 10, -85)
    triggerLabel:SetText("Trigger")
    local triggerDD = MakeDropDown(box, 170, -78, 160)

    local p = {}
    p.invertCB = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    p.invertCB:SetPoint("LEFT", triggerDD, "LEFT", -20, 2)
    p.invertT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.invertT:SetPoint("LEFT", p.invertCB, "LEFT", -40, 0)
    p.invertT:SetText("Invert")

    local effectLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    effectLabel:SetPoint("TOPLEFT", 10, -120)
    effectLabel:SetText("Effect")
    local effectDD = MakeDropDown(box, 70, -112, 260)

    local paramsLabel = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paramsLabel:SetPoint("TOPLEFT", 360, -53)
    paramsLabel:SetText("Params")

    local x1, y1 = 360, -78
    local x2, y2 = 360, -108

    p.threatMinDD = MakeDropDown(box, x1, y1, 110)
    p.threatMinL = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.threatMinL:SetPoint("BOTTOMLEFT", p.threatMinDD, "TOPLEFT", 16, 2)
    p.threatMinL:SetText("Min (2/3)")

    p.hpBelowEdit = MakeEdit(box, x1, y1, 80)
    p.hpBelowL = MakeSmallLabel(box, p.hpBelowEdit, "HP% below")

    p.itemDD = MakeDropDown(box, x1, y1, 180)
    p.itemL = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.itemL:SetPoint("BOTTOMLEFT", p.itemDD, "TOPLEFT", 16, 2)
    p.itemL:SetText("Item in bags")

    p.itemBelowEdit = MakeEdit(box, x1 + 280, y1, 20)
    p.itemBelowL = MakeSmallLabel(box, p.itemBelowEdit, "Count below")

    p.itemIdManual = MakeEdit(box, x1 + 210, y1, 50)
    p.itemIdManualL = MakeSmallLabel(box, p.itemIdManual, "ItemId")

    p.unitDD = MakeDropDown(box, x1, y1, 110)
    p.unitL = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.unitL:SetPoint("BOTTOMLEFT", p.unitDD, "TOPLEFT", 16, 2)
    p.unitL:SetText("Unit")

    p.auraEdit = MakeEdit(box, x1 + 140, y1 - 3, 260)
    p.auraL = MakeSmallLabel(box, p.auraEdit, "Aura name (exact)")

    p.friendlyOnly = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    p.friendlyOnly:SetPoint("TOPLEFT", x1, y2)
    p.friendlyOnlyT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.friendlyOnlyT:SetPoint("LEFT", p.friendlyOnly, "RIGHT", 4, 0)
    p.friendlyOnlyT:SetText("Target must be friendly")

    p.debuffEdit = MakeEdit(box, x1, y1, 320)
    p.debuffL = MakeSmallLabel(box, p.debuffEdit, "Debuff name (exact)")

    -- TotemSlot dropdown (verplicht)
    p.totemSlotDD = MakeDropDown(box, x1, y1, 120)
    p.totemSlotL = MakeSmallLabel(box, p.totemSlotDD, "Totem slot")

    p.staticCB = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    p.staticT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.staticT:SetPoint("LEFT", p.staticCB, "RIGHT", 4, 0)
    p.staticT:SetText("Static")

    p.procCB = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
    p.procCB:SetPoint("LEFT", p.staticT, "RIGHT", 10, 0)
    p.procT = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.procT:SetPoint("LEFT", p.procCB, "RIGHT", 4, 0)
    p.procT:SetText("Show as proc")

    p.colorDD = MakeDropDown(box, x1, y2, 180)
    p.colorL = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.colorL:SetPoint("BOTTOMLEFT", p.colorDD, "TOPLEFT", 16, 2)
    p.colorL:SetText("Color")

    p.staticCB:SetPoint("LEFT", p.colorDD, "RIGHT", -12, 2)

    local ui = {
      idx = idx,
      box = box,
      enabled = enabled,
      force = force,
      triggerDD = triggerDD,
      effectDD = effectDD,
      params = p,
      _ShowPair = ShowPair,
    }
    return ui
  end

  C.rulesUI[1] = CreateRuleBlock(1, -96)
  C.rulesUI[2] = CreateRuleBlock(2, -262)
  C.rulesUI[3] = CreateRuleBlock(3, -428)

  local function HideAllParams(ui)
    local p = ui.params
    ui._ShowPair(p.invertCB, p.invertT, false)
    ui._ShowPair(p.threatMinDD, p.threatMinL, false)
    ui._ShowPair(p.hpBelowEdit, p.hpBelowL, false)
    ui._ShowPair(p.itemDD, p.itemL, false)
    ui._ShowPair(p.itemBelowEdit, p.itemBelowL, false)
    ui._ShowPair(p.itemIdManual, p.itemIdManualL, false)
    ui._ShowPair(p.unitDD, p.unitL, false)
    ui._ShowPair(p.auraEdit, p.auraL, false)
    ui._ShowPair(p.friendlyOnly, p.friendlyOnlyT, false)
    ui._ShowPair(p.debuffEdit, p.debuffL, false)
    ui._ShowPair(p.staticCB, p.staticT, false)
    ui._ShowPair(p.colorDD, p.colorL, false)
    ui._ShowPair(p.procCB, p.procT, false)
    ui._ShowPair(p.totemSlotDD, p.totemSlotL, false)
  end

  local function ShowParamsForTrigger(ui, rule)
    HideAllParams(ui)
    local p = ui.params
    local trigger = rule.trigger

    if trigger ~= "NONE" then
      ui._ShowPair(p.invertCB, p.invertT, true)
    end

    if trigger == "THREAT_AT_LEAST" then
      ui._ShowPair(p.threatMinDD, p.threatMinL, true)
    elseif trigger == "TARGET_HP_BELOW" then
      ui._ShowPair(p.hpBelowEdit, p.hpBelowL, true)
    elseif trigger == "ITEM_COUNT_BELOW" then
      ui._ShowPair(p.itemDD, p.itemL, true)
      ui._ShowPair(p.itemBelowEdit, p.itemBelowL, true)
      ui._ShowPair(p.itemIdManual, p.itemIdManualL, true)
    elseif trigger == "MISSING_BUFF" then
      ui._ShowPair(p.unitDD, p.unitL, true)
      ui._ShowPair(p.auraEdit, p.auraL, true)
      local unit = (rule.params and rule.params.unit) or "player"
      ui._ShowPair(p.friendlyOnly, p.friendlyOnlyT, unit == "target")
    elseif trigger == "MISSING_DEBUFF_TARGET" then
      ui._ShowPair(p.debuffEdit, p.debuffL, true)
    elseif trigger == "TOTEM_SLOT_MISSING" then
      ui._ShowPair(p.totemSlotDD, p.totemSlotL, true)
    end
  end

  local function ShowParamsForEffect(ui, rule)
    local p = ui.params
    local lane = ExtendedUI.LANE[ui.idx]
    ui._ShowPair(p.staticCB, p.staticT, false)
    ui._ShowPair(p.colorDD, p.colorL, false)
    if (lane == "A" and rule.effect == "GLOW_BORDER") then
      ui._ShowPair(p.staticCB, p.staticT, true)
      ui._ShowPair(p.procCB, p.procT, true)
      ui._ShowPair(p.colorDD, p.colorL, true)
    elseif (lane == "B" and rule.effect == "FLASH") then
      ui._ShowPair(p.colorDD, p.colorL, true)
    elseif (lane == "A" and (rule.effect == "AUTOCAST_RINGS" or rule.effect == "AUTOCAST_SPARKLES")) then
      ui._ShowPair(p.colorDD, p.colorL, true)
    end
  end

  local function Refresh()
    local prof = ExtendedUI_DB.profile
    C.enabledCB:SetChecked(prof.global.enabled)
    local barId, slot = C.state.barId, C.state.slot

    for i = 1, ExtendedUI.RULES_PER_SLOT do
      local ui = C.rulesUI[i]
      local rule = EnsureRule(prof, barId, slot, i)
      ui.enabled:SetChecked(rule.enabled)
      ui.force:SetChecked(rule.debugForceOn)
      ui.enabled:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.enabled = self:GetChecked() and true or false
      end)
      ui.force:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.debugForceOn = self:GetChecked() and true or false
      end)
      UIDropDownMenu_Initialize(ui.triggerDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, o in ipairs(TriggerOptions()) do
          info.text = o.text
          info.checked = (rule.trigger == o.key)
          info.func = function()
            local r = GetCurrentRule(i)
            r.trigger = o.key
            UIDropDownMenu_SetText(ui.triggerDD, o.text)
            ShowParamsForTrigger(ui, r)
            ShowParamsForEffect(ui, r)
            Refresh()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      UIDropDownMenu_SetText(ui.triggerDD, rule.trigger)
      ui.params.invertCB:SetChecked(rule.params and rule.params.invert and true or false)
      ui.params.invertCB:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.params = r.params or {}
        r.params.invert = self:GetChecked() and true or false
      end)
      local lane = ExtendedUI.LANE[i]
      UIDropDownMenu_Initialize(ui.effectDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, o in ipairs(EffectOptionsForLane(lane)) do
          info.text = o.text
          info.checked = (rule.effect == o.key)
          info.func = function()
            local r = GetCurrentRule(i)
            r.effect = o.key
            UIDropDownMenu_SetText(ui.effectDD, o.text)
            ShowParamsForEffect(ui, r)
            Refresh()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      UIDropDownMenu_SetText(ui.effectDD, rule.effect)
      ShowParamsForTrigger(ui, rule)
      ShowParamsForEffect(ui, rule)
      UIDropDownMenu_Initialize(ui.params.threatMinDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, v in ipairs({ 2, 3 }) do
          info.text = tostring(v)
          info.checked = (tonumber(rule.params.min) == v)
          info.func = function()
            local r = GetCurrentRule(i)
            r.params.min = v
            UIDropDownMenu_SetText(ui.params.threatMinDD, tostring(v))
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      UIDropDownMenu_SetText(ui.params.threatMinDD, tostring(rule.params.min or 3))
      ui.params.hpBelowEdit:SetText(tostring(rule.params.below or 20))
      ui.params.hpBelowEdit:SetScript("OnTextChanged", function(self)
        local r = GetCurrentRule(i)
        local v = tonumber(self:GetText())
        if v then r.params.below = v end
      end)
      UIDropDownMenu_Initialize(ui.params.itemDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "(select item)"
        info.checked = false
        info.func = function() end
        UIDropDownMenu_AddButton(info, level)
        for _, it in ipairs(BagItems.list) do
          local label = string.format("%s (id:%d, x%d)", it.name, it.id, it.count)
          info.text = label
          info.checked = (tonumber(rule.params.itemId) == it.id)
          info.func = function()
            local r = GetCurrentRule(i)
            r.params.itemId = it.id
            ui.params.itemIdManual:SetText(tostring(it.id))
            UIDropDownMenu_SetText(ui.params.itemDD, it.name)
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      do
        local currentId = tonumber(rule.params.itemId)
        local currentName = currentId and (GetItemInfo(currentId) or ("item:" .. currentId)) or "(select item)"
        UIDropDownMenu_SetText(ui.params.itemDD, currentName)
      end
      ui.params.itemBelowEdit:SetText(tostring(rule.params.below or 5))
      ui.params.itemBelowEdit:SetScript("OnTextChanged", function(self)
        local r = GetCurrentRule(i)
        local v = tonumber(self:GetText())
        if v then r.params.below = v end
      end)
      ui.params.itemIdManual:SetText(rule.params.itemId and tostring(rule.params.itemId) or "")
      ui.params.itemIdManual:SetScript("OnTextChanged", function(self)
        local r = GetCurrentRule(i)
        local id = tonumber(self:GetText())
        if id then r.params.itemId = id end
      end)
      UIDropDownMenu_Initialize(ui.params.unitDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, u in ipairs({ "player", "target" }) do
          info.text = u
          info.checked = (rule.params.unit == u)
          info.func = function()
            local r = GetCurrentRule(i)
            r.params.unit = u
            UIDropDownMenu_SetText(ui.params.unitDD, u)
            ShowParamsForTrigger(ui, r)
            ShowParamsForEffect(ui, r)
            Refresh()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      UIDropDownMenu_SetText(ui.params.unitDD, rule.params.unit or "player")
      ui.params.auraEdit:SetText(rule.params.auraName or "")
      ui.params.auraEdit:SetScript("OnTextChanged", function(self)
        local r = GetCurrentRule(i)
        r.params.auraName = self:GetText()
      end)
      ui.params.friendlyOnly:SetChecked(rule.params.targetFriendlyOnly and true or false)
      ui.params.friendlyOnly:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.params.targetFriendlyOnly = self:GetChecked() and true or false
      end)
      ui.params.debuffEdit:SetText(rule.params.auraName or "")
      ui.params.debuffEdit:SetScript("OnTextChanged", function(self)
        local r = GetCurrentRule(i)
        r.params.auraName = self:GetText()
      end)
      ui.params.staticCB:SetChecked(rule.effectParams and rule.effectParams.static and true or false)
      ui.params.staticCB:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.effectParams = r.effectParams or {}
        r.effectParams.static = self:GetChecked() and true or false
      end)
      ui.params.procCB:SetChecked(rule.effectParams and rule.effectParams.showAsProc and true or false)
      ui.params.procCB:SetScript("OnClick", function(self)
        local r = GetCurrentRule(i)
        r.effectParams = r.effectParams or {}
        r.effectParams.showAsProc = self:GetChecked() and true or false
        if ExtendedUI and ExtendedUI.UpdateProcDisplay then
          ExtendedUI:UpdateProcDisplay()
        end
      end)
      UIDropDownMenu_Initialize(ui.params.colorDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, c in ipairs(ColorOptions()) do
          info.text = c.text
          info.checked = ((rule.effectParams and rule.effectParams.color) == c.key)
          info.func = function()
            local r = GetCurrentRule(i)
            r.effectParams = r.effectParams or {}
            r.effectParams.color = c.key
            UIDropDownMenu_SetText(ui.params.colorDD, c.text)
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      do
        local key = (rule.effectParams and rule.effectParams.color)
        if type(key) ~= "string" then key = "GOLD" end
        UIDropDownMenu_SetText(ui.params.colorDD, ColorKeyToText(key))
      end
      -- TotemSlot dropdown (verplicht)
      UIDropDownMenu_Initialize(ui.params.totemSlotDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, slotInfo in ipairs(TotemSlotLookup) do
          info.text = slotInfo.txt
          info.checked = (tonumber(rule.params.totemSlot) == slotInfo.num)
          info.func = function()
            local r = GetCurrentRule(i)
            r.params.totemSlot = slotInfo.num
            UIDropDownMenu_SetText(ui.params.totemSlotDD, slotInfo.txt)
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      do
        local slot = rule.params.totemSlot
        if tonumber(slot) then
          UIDropDownMenu_SetText(ui.params.totemSlotDD, TotemSlotNumToText(slot))
        else
          UIDropDownMenu_SetText(ui.params.totemSlotDD, "Select slot")
        end
      end
    end
  end

  C.Refresh = Refresh

  C.enabledCB:SetScript("OnClick", function(self)
    ExtendedUI_DB.profile.global.enabled = self:GetChecked() and true or false
  end)

  ScanBags()
  w:Hide()
end

function C.Toggle()
  if InCombatLockdown and InCombatLockdown() then
    print("ExtendedUI: can't open config in combat.")
    return
  end

  EnsureWindow()
  if C.win:IsShown() then
    C.win:Hide()
  else
    C.win:Show()
    if C.Refresh then C.Refresh() end
  end
end