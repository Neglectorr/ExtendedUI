EUI_Effects = {}
local FX = EUI_Effects

local math_sin = math.sin
local math_cos = math.cos
local math_floor = math.floor
local math_min = math.min
local math_pi = math.pi
local unpack = unpack

local function GetOverlay(btn)
  return btn and btn.ExtendedUIOverlay
end

local function Pulse(now, speed)
  speed = tonumber(speed) or 1.0
  return 0.5 + 0.5 * math_sin(now * (math_pi * 2) * speed)
end

local function GetColor(rule)
  local key = rule and rule.effectParams and rule.effectParams.color or "GOLD"
  local colors = {
    GOLD   = { 1.00, 0.82, 0.10 },
    RED    = { 1.00, 0.10, 0.10 },
    GREEN  = { 0.10, 1.00, 0.10 },
    BLUE   = { 0.20, 0.55, 1.00 },
    YELLOW = { 1.00, 0.90, 0.15 },
    ORANGE = { 1.00, 0.55, 0.10 },
    PURPLE = { 0.75, 0.25, 1.00 },
    CYAN   = { 0.10, 0.95, 0.95 },
    WHITE  = { 1.00, 1.00, 1.00 },
  }
  return unpack(colors[key] or colors.GOLD)
end

FX.APPLY = {}
FX.APPLY.NONE = function() end

FX.APPLY.GLOW_BORDER = function(rule, ctx)
  local o = GetOverlay(ctx.button)
  if not o or not o.glow then return end

  local r, g, b = GetColor(rule)
  local isStatic = rule.effectParams and rule.effectParams.static

  local a
  if isStatic then
    a = 1.0
  else
    local p = Pulse(ctx.now, 1.2)
    a = 1.0 * p
  end

  o.glow:SetVertexColor(r, g, b, a)
  o.glow:Show()
end

FX.APPLY.AUTOCAST_RINGS = function(rule, ctx)
  local o = GetOverlay(ctx.button)
  if not o or not o.ring1 or not o.ring2 then return end

  local r, g, b = GetColor(rule)
  local p = 0.25 + 0.75 * Pulse(ctx.now, 0.9)

  o.ring1:SetVertexColor(r, g, b, (0.85 * p))
  o.ring2:SetVertexColor(r, g, b, (0.85 * p))

  local rot = ctx.now * 0.9
  o.ring1:SetRotation(rot)
  o.ring2:SetRotation(-rot * 1.3)

  o.ring1:Show()
  o.ring2:Show()
end

FX.APPLY.AUTOCAST_SPARKLES = function(rule, ctx)
  local o = GetOverlay(ctx.button)
  if not o or not o.sparkFrame or not o.sparkles then return end

  local sparkles = o.sparkles
  local n = #sparkles
  if n == 0 then return end

  o.sparkFrame:Show()
  for i = 1, n do sparkles[i]:Show() end

  local w = o:GetWidth() or 0
  local h = o:GetHeight() or 0
  if w <= 0 or h <= 0 then return end

  local radius = (math_min(w, h) / 2) - 4
  local step = (2 * math_pi) / n

  if (not o._sparkLayout) or o._sparkW ~= w or o._sparkH ~= h then
    o._sparkLayout = true
    o._sparkW, o._sparkH = w, h
    o._sparkRadius = radius

    local baseSize = 10
    for i = 1, n do
      local t = sparkles[i]
      t:SetSize(baseSize, baseSize)

      local a = (i - 1) * step
      local x = math_cos(a) * radius
      local y = math_sin(a) * radius
      t:ClearAllPoints()
      t:SetPoint("CENTER", o, "CENTER", x, y)
    end
  end

  local speed = 6.0
  local headIndex = (math_floor(ctx.now * speed) % n) + 1

  local K = 4
  local aMax = 0.85
  local aMin = 0.05

  for i = 1, n do sparkles[i]:SetAlpha(aMin) end

  for k = 0, K - 1 do
    local idx = headIndex - k
    if idx <= 0 then idx = idx + n end

    local t = 1
    if K > 1 then t = 1 - (k / (K - 1)) end
    local alpha = aMin + (aMax - aMin) * t
    sparkles[idx]:SetAlpha(alpha)
  end
end

FX.APPLY.FLASH = function(rule, ctx)
  local o = GetOverlay(ctx.button)
  if not o or not o.flash then return end

  local r, g, b = GetColor(rule)
  local p = Pulse(ctx.now, 1)
  o.flash:SetVertexColor(r, g, b, (0.60 * p))
  o.flash:Show()
end

FX.APPLY.ICON_TINT = function(rule, ctx)
  local o = GetOverlay(ctx.button)
  if not o or not o.icon then return end
  o.icon:SetVertexColor(1, 1, 1, 1)
  o.icon:SetAlpha(0.5)
end

function FX.Apply(rule, ctx)
  local fn = FX.APPLY[rule.effect]
  if not fn then return end
  fn(rule, ctx)
end