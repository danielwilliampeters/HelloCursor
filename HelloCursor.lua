-- HelloCursor: cursor ring addon (Retail)

local ADDON_NAME = ...
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

HelloCursorDB = HelloCursorDB or {}

-- ---------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------

local DEFAULTS = {
  enabled = true,
  colorHex = "FF4FD8",
  useClassColor = false,
  size = 96,
  showWorld = true,
  showPvE = true,
  showPvP = true,
  showInCombat = true,
  hideInMenus = true,
  reactiveCursor = true,
  showGCDSpinner = false,
  useNeonRing = false,
}

-- Authored ring sizes (constant stroke thickness per asset)
local RING_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\ring_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\ring_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\ring_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\ring_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\ring_128.tga",
}

local RING_SMALL_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\ring_small_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\ring_small_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\ring_small_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\ring_small_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\ring_small_128.tga",
}

local NEON_CORE_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_core_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_core_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_core_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_core_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_core_128.tga",
}

local NEON_CORE_SMALL_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_core_small_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_core_small_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_core_small_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_core_small_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_core_small_128.tga",
}

local NEON_INNER_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_inner_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_inner_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_inner_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_inner_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_inner_128.tga",
}

local NEON_INNER_SMALL_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_inner_small_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_inner_small_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_inner_small_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_inner_small_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_inner_small_128.tga",
}

local NEON_OUTER_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_outer_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_outer_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_outer_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_outer_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_outer_128.tga",
}

local NEON_OUTER_SMALL_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\neon_outer_small_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\neon_outer_small_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\neon_outer_small_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\neon_outer_small_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\neon_outer_small_128.tga",
}

-- ---------------------------------------------------------------------
-- Tunables
-- ---------------------------------------------------------------------

local TWEEN_DURATION = 0.08
local GCD_SPELL_ID = 61304 -- "Global Cooldown"
local GCD_POP_CHECK_INTERVAL = 0.02 -- interval for polling GCD state

-- Pop at end of GCD (a quick scale pulse on the ring frame)
local GCD_POP_ENABLED   = true
local GCD_POP_SCALE     = 1.16
local GCD_POP_UP_TIME   = 0.045
local GCD_POP_DOWN_TIME = 0.075

-- Fixed canvas so ring thickness never scales (textures are authored for this)
local RING_CANVAS_SIZE = 128

local NEON_ALPHA_CORE  = 1.00
local NEON_ALPHA_INNER = 0.30
local NEON_ALPHA_OUTER = 0.08

local DEBUG_NEON_SHOW_CORE  = true
local DEBUG_NEON_SHOW_INNER = true
local DEBUG_NEON_SHOW_OUTER = true

-- ---------------------------------------------------------------------
-- Small utils
-- ---------------------------------------------------------------------

-- Cache a few frequently used globals in locals for tiny per-frame savings.
local GetTime             = GetTime
local GetCursorPosition   = GetCursorPosition
local IsMouselooking      = IsMouselooking
local UnitAffectingCombat = UnitAffectingCombat
local IsInInstance        = IsInInstance
local math_abs            = math.abs

local function CopyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = v end
  end
  return dst
end

local function Clamp(n, lo, hi)
  n = tonumber(n) or lo
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function Lerp(a, b, t) return a + (b - a) * t end
local function EaseInOut(t)
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  return t * t * (3 - 2 * t)
end

local function NormalizeHex(hex)
  if not hex then return nil end
  hex = tostring(hex):gsub("%s+", ""):gsub("#", ""):upper()
  if (#hex == 6 or #hex == 8) and hex:match("^[0-9A-F]+$") then
    return hex
  end
  return nil
end

local function HexToRGBA(hex)
  hex = NormalizeHex(hex) or DEFAULTS.colorHex

  if #hex == 6 then
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 79
    local b = tonumber(hex:sub(5, 6), 16) or 216
    return r / 255, g / 255, b / 255, 1
  else
    local a = tonumber(hex:sub(1, 2), 16) or 255
    local r = tonumber(hex:sub(3, 4), 16) or 255
    local g = tonumber(hex:sub(5, 6), 16) or 79
    local b = tonumber(hex:sub(7, 8), 16) or 216
    return r / 255, g / 255, b / 255, a / 255
  end
end

local function RGBAtoHex(r, g, b)
  r = Clamp(math.floor((r or 1) * 255 + 0.5), 0, 255)
  g = Clamp(math.floor((g or 0) * 255 + 0.5), 0, 255)
  b = Clamp(math.floor((b or 1) * 255 + 0.5), 0, 255)
  return string.format("%02X%02X%02X", r, g, b)
end

local function SafeSetTexture(tex, path, fallback)
  local ok = tex:SetTexture(path)
  if not ok and fallback then
    tex:SetTexture(fallback)
  end
end

local function NearestKey(map, target)
  local bestKey, bestDist
  for k in pairs(map) do
    local d = math_abs(k - target)
    if not bestDist or d < bestDist then
      bestDist, bestKey = d, k
    end
  end
  return bestKey
end

local function GetSpellCooldownCompat(spellID)
  if C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(spellID)
    if info then
      local startTime = info.startTime or 0
      local duration  = info.duration or 0
      local enabled   = info.isEnabled
      if enabled == nil then enabled = true end
      return startTime, duration, enabled and 1 or 0
    end
  end

  if GetSpellCooldown then
    local startTime, duration, enabled = GetSpellCooldown(spellID)
    return startTime or 0, duration or 0, enabled or 0
  end

  return 0, 0, 0
end

-- ---------------------------------------------------------------------
-- Visibility rules
-- ---------------------------------------------------------------------

local function IsAnyMenuOpen()
  -- Main ESC menu
  if GameMenuFrame and GameMenuFrame:IsShown() then return true end

  -- Dragonflight settings panel
  if SettingsPanel and SettingsPanel:IsShown() then return true end

  -- Older options frames (still present on some clients)
  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then return true end
  if VideoOptionsFrame and VideoOptionsFrame:IsShown() then return true end
  if AudioOptionsFrame and AudioOptionsFrame:IsShown() then return true end

  return false
end

local function IsAllowedInZone()
  if HelloCursorDB.showInCombat and UnitAffectingCombat("player") then
    return true
  end

  local inInstance, instanceType = IsInInstance()
  if not inInstance then
    return HelloCursorDB.showWorld
  end

  if instanceType == "pvp" or instanceType == "arena" then
    return HelloCursorDB.showPvP
  end

  return HelloCursorDB.showPvE
end

local function IsAddonEnabled()
  -- Prefer the Settings-backed namespaced value if it exists, to ensure
  -- the Blizzard Settings checkbox always wins. Mirror it back into the
  -- plain DB field so the rest of the addon has a single source of truth.
  local nsKey = "HelloCursor_enabled"
  local enabled = HelloCursorDB.enabled
  if type(HelloCursorDB[nsKey]) == "boolean" then
    enabled = HelloCursorDB[nsKey]
  end
  if enabled == nil then
    enabled = DEFAULTS.enabled and true or false
  end
  HelloCursorDB.enabled = enabled
  return enabled
end

-- Temporary override: allow ring to show while using the colour picker
local forceShowWhilePickingColour = false

local function ShouldShowRing()
  if not IsAddonEnabled() then
    return false
  end

  if (not forceShowWhilePickingColour) and HelloCursorDB.hideInMenus and IsAnyMenuOpen() then
    return false
  end

  return IsAllowedInZone()
end

-- ---------------------------------------------------------------------
-- Frame + textures
-- ---------------------------------------------------------------------

local ringFrame = CreateFrame("Frame", "HelloCursorFrame", UIParent)
local ringTexNormal = ringFrame:CreateTexture(nil, "OVERLAY")
local ringTexSmall = ringFrame:CreateTexture(nil, "OVERLAY")

ringFrame:SetFrameStrata("TOOLTIP")
ringFrame:SetSize(RING_CANVAS_SIZE, RING_CANVAS_SIZE)
ringFrame:Hide()
ringTexNormal:SetAllPoints(true)
ringTexSmall:SetAllPoints(true)

-- Neon layers (optional style)
local neonCoreNormal  = ringFrame:CreateTexture(nil, "BACKGROUND")
local neonCoreSmall   = ringFrame:CreateTexture(nil, "BACKGROUND")
local neonOuterNormal = ringFrame:CreateTexture(nil, "BORDER")
local neonOuterSmall  = ringFrame:CreateTexture(nil, "BORDER")
local neonInnerNormal = ringFrame:CreateTexture(nil, "BORDER")
local neonInnerSmall  = ringFrame:CreateTexture(nil, "BORDER")

neonCoreNormal:SetAllPoints(true)
neonCoreSmall:SetAllPoints(true)
neonOuterNormal:SetAllPoints(true)
neonOuterSmall:SetAllPoints(true)
neonInnerNormal:SetAllPoints(true)
neonInnerSmall:SetAllPoints(true)

-- Core behind, glows above it
neonCoreNormal:SetDrawLayer("BACKGROUND", 0)
neonCoreSmall:SetDrawLayer("BACKGROUND", 0)
neonCoreNormal:SetBlendMode("BLEND")
neonCoreSmall:SetBlendMode("BLEND")

neonOuterNormal:SetDrawLayer("BORDER", 0)
neonOuterSmall:SetDrawLayer("BORDER", 0)
neonOuterNormal:SetBlendMode("ADD")
neonOuterSmall:SetBlendMode("ADD")

neonInnerNormal:SetDrawLayer("BORDER", 1)
neonInnerSmall:SetDrawLayer("BORDER", 1)
neonInnerNormal:SetBlendMode("ADD")
neonInnerSmall:SetBlendMode("ADD")

-- Initial textures (overridden by RefreshSize)
SafeSetTexture(ringTexNormal, RING_TEX_BY_SIZE[96], nil)
SafeSetTexture(ringTexSmall,  RING_SMALL_TEX_BY_SIZE[96], RING_TEX_BY_SIZE[96])

SafeSetTexture(neonCoreNormal,  NEON_CORE_TEX_BY_SIZE[96],  nil)
SafeSetTexture(neonCoreSmall,   NEON_CORE_SMALL_TEX_BY_SIZE[96], NEON_CORE_TEX_BY_SIZE[96])
SafeSetTexture(neonInnerNormal, NEON_INNER_TEX_BY_SIZE[96], nil)
SafeSetTexture(neonInnerSmall,  NEON_INNER_SMALL_TEX_BY_SIZE[96], NEON_INNER_TEX_BY_SIZE[96])
SafeSetTexture(neonOuterNormal, NEON_OUTER_TEX_BY_SIZE[96], nil)
SafeSetTexture(neonOuterSmall,  NEON_OUTER_SMALL_TEX_BY_SIZE[96], NEON_OUTER_TEX_BY_SIZE[96])

-- GCD spinners (normal + small), crossfaded like the ring
local gcdSpinnerNormal = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
gcdSpinnerNormal:SetAllPoints(true)
gcdSpinnerNormal:SetFrameLevel(ringFrame:GetFrameLevel() + 5)
gcdSpinnerNormal:Hide()

local gcdSpinnerSmall = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
gcdSpinnerSmall:SetAllPoints(true)
gcdSpinnerSmall:SetFrameLevel(ringFrame:GetFrameLevel() + 5)
gcdSpinnerSmall:Hide()

local function SetupSpinner(f)
  if f.SetHideCountdownNumbers then f:SetHideCountdownNumbers(true) end
  if f.SetDrawBling then f:SetDrawBling(false) end
  if f.SetDrawEdge then f:SetDrawEdge(false) end
end

SetupSpinner(gcdSpinnerNormal)
SetupSpinner(gcdSpinnerSmall)
if gcdSpinnerNormal.SetSwipeTexture then
  gcdSpinnerNormal:SetSwipeTexture(RING_TEX_BY_SIZE[96])
end
if gcdSpinnerSmall.SetSwipeTexture then
  gcdSpinnerSmall:SetSwipeTexture(RING_SMALL_TEX_BY_SIZE[96])
end

local function IsNeonStyle()
  return HelloCursorDB.useNeonRing and true or false
end

local function SetShownSafe(tex, show)
  if not tex then return end
  if tex.SetShown then
    tex:SetShown(show)
  else
    if show then tex:Show() else tex:Hide() end
  end
end

local function SetStyleVisibility()
  local neon = IsNeonStyle()

  -- flat ring
  SetShownSafe(ringTexNormal, not neon)
  SetShownSafe(ringTexSmall,  not neon)

  -- neon layers
  SetShownSafe(neonOuterNormal, neon and DEBUG_NEON_SHOW_OUTER)
  SetShownSafe(neonOuterSmall,  neon and DEBUG_NEON_SHOW_OUTER)

  SetShownSafe(neonInnerNormal, neon and DEBUG_NEON_SHOW_INNER)
  SetShownSafe(neonInnerSmall,  neon and DEBUG_NEON_SHOW_INNER)

  SetShownSafe(neonCoreNormal,  neon and DEBUG_NEON_SHOW_CORE)
  SetShownSafe(neonCoreSmall,   neon and DEBUG_NEON_SHOW_CORE)
end

-- ---------------------------------------------------------------------
-- Colour (class colour or hex)
-- ---------------------------------------------------------------------

local function GetPlayerClassRGB()
  local _, classFile = UnitClass("player")
  classFile = classFile or "PRIEST"

  if C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c and c.GetRGB then
      return c:GetRGB()
    elseif c and c.r then
      return c.r, c.g, c.b
    end
  end

  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return c.r, c.g, c.b
  end

  if GetClassColor then
    local r, g, b = GetClassColor(classFile)
    return r, g, b
  end

  return 1, 1, 1
end

local lastTintKey = nil

local function ComputeTint()
  if HelloCursorDB.useClassColor then
    local r, g, b = GetPlayerClassRGB()
    return r, g, b, 1, ("class:%0.4f:%0.4f:%0.4f"):format(r, g, b)
  end

  local r, g, b, a = HexToRGBA(HelloCursorDB.colorHex)
  return r, g, b, a, ("hex:%s"):format(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
end

local function ApplyTintIfNeeded(force)
  local r, g, b, a, key = ComputeTint()
  if force or key ~= lastTintKey then
    ringTexNormal:SetVertexColor(r, g, b, a)
    ringTexSmall:SetVertexColor(r, g, b, a)
    if gcdSpinnerNormal and gcdSpinnerNormal.SetSwipeColor then
      gcdSpinnerNormal:SetSwipeColor(r, g, b, a or 1)
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetSwipeColor then
      gcdSpinnerSmall:SetSwipeColor(r, g, b, a or 1)
    end
    lastTintKey = key
  end

  local neon = IsNeonStyle()
  if neon then
    local tintA = a or 1

    neonCoreNormal:SetVertexColor(r, g, b, tintA)
    neonCoreSmall:SetVertexColor(r, g, b, tintA)

    neonOuterNormal:SetVertexColor(r, g, b, tintA)
    neonOuterSmall:SetVertexColor(r, g, b, tintA)

    neonInnerNormal:SetVertexColor(1, 1, 1, tintA)
    neonInnerSmall:SetVertexColor(1, 1, 1, tintA)
  end
end

-- ---------------------------------------------------------------------
-- Crossfade state
-- ---------------------------------------------------------------------

local currentMix = 0
local WantsSmallRing -- forward decl
local SetMix         -- forward decl
local UpdateRingPosition -- forward decl (needed for picker driver)

local pickerDriver

local lastTexKey = 96
local lastGCDRemaining = 0
local lastGCDBusy = false
local gcdVisualActive = false -- when true, spinner replaces the ring visuals
local gcdPopPlaying = false
local suppressFlatRing = false
local gcdCheckAccum = 0

-- ---------------------------------------------------------------------
-- GCD end pop
-- ---------------------------------------------------------------------

local gcdPopAnim = ringFrame:CreateAnimationGroup()

local popUp = gcdPopAnim:CreateAnimation("Scale")
popUp:SetOrder(1)
if popUp.SetScaleFrom then popUp:SetScaleFrom(1, 1) end
popUp:SetScale(GCD_POP_SCALE, GCD_POP_SCALE)
popUp:SetDuration(GCD_POP_UP_TIME)
popUp:SetSmoothing("OUT")

local popDown = gcdPopAnim:CreateAnimation("Scale")
popDown:SetOrder(2)
if popDown.SetScaleFrom then popDown:SetScaleFrom(GCD_POP_SCALE, GCD_POP_SCALE) end
popDown:SetScale(1, 1)
popDown:SetDuration(GCD_POP_DOWN_TIME)
popDown:SetSmoothing("IN")

gcdPopAnim:SetScript("OnPlay", function()
  gcdPopPlaying = true

  -- Pop is a pulse on the RING, so ensure the ring visuals are active.
  gcdVisualActive = false
  suppressFlatRing = false

  if gcdSpinnerNormal then gcdSpinnerNormal:Hide() end
  if gcdSpinnerSmall then gcdSpinnerSmall:Hide() end

  if SetMix then SetMix(currentMix) end
end)

gcdPopAnim:SetScript("OnFinished", function()
  gcdPopPlaying = false
end)

gcdPopAnim:SetScript("OnStop", function()
  gcdPopPlaying = false
end)

local function TriggerGCDPop()
  if not GCD_POP_ENABLED then return end
  if not ringFrame:IsShown() then return end
  if not HelloCursorDB.showGCDSpinner then return end

  if gcdPopAnim:IsPlaying() then
    gcdPopAnim:Stop()
  end
  gcdPopAnim:Play()
end

local function CheckGCDPop()
  if not HelloCursorDB.showGCDSpinner then
    return
  end

  local now = GetTime()
  local startTime, duration, enabled = GetSpellCooldownCompat(GCD_SPELL_ID)
  local gcdActive = false
  local remaining = 0

  if enabled ~= 0 and duration and duration > 0 and startTime and startTime > 0 then
    remaining = (startTime + duration) - now
    gcdActive = remaining > 0
  end

  -- Pop when GCD ends (normal case: we observe busy -> idle)
  if lastGCDBusy and (not gcdActive) then
    TriggerGCDPop()
  end

  -- Pop when a NEW GCD starts immediately after the old one ended
  -- (we missed the idle state between samples).
  -- Only fire this if the previous remaining was already near-zero.
  if lastGCDBusy and gcdActive and (remaining > lastGCDRemaining + 0.02) and (lastGCDRemaining > 0) and (lastGCDRemaining < 0.08) then
    TriggerGCDPop()
  end

  -- Spinner / ring base visibility
  local wantSpinner = HelloCursorDB.showGCDSpinner and gcdActive and (not gcdPopPlaying)

  gcdVisualActive = wantSpinner
  suppressFlatRing = wantSpinner


  if wantSpinner and not IsNeonStyle() then
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(0)
  end

  if wantSpinner then
    if gcdSpinnerNormal and gcdSpinnerNormal.SetCooldown then
      gcdSpinnerNormal:SetCooldown(startTime, duration)
      gcdSpinnerNormal:Show()
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetCooldown then
      gcdSpinnerSmall:SetCooldown(startTime, duration)
      gcdSpinnerSmall:Show()
    end

    if gcdSpinnerNormal then gcdSpinnerNormal:SetAlpha(1 - currentMix) end
    if gcdSpinnerSmall  then gcdSpinnerSmall:SetAlpha(currentMix) end
    
  else
    if gcdSpinnerNormal then gcdSpinnerNormal:Hide() end
    if gcdSpinnerSmall then gcdSpinnerSmall:Hide() end
  end

  gcdVisualActive = wantSpinner
  if not gcdVisualActive and SetMix then
    -- Restore ring visuals according to the current mix
    SetMix(currentMix)
  end

  lastGCDBusy = gcdActive
  lastGCDRemaining = remaining
end

-- ---------------------------------------------------------------------
-- Crossfade tween (normal <-> small)
-- mix: 0 = normal, 1 = small
-- ---------------------------------------------------------------------

local tweenActive = false
local tweenStart = 0
local tweenFrom = 0
local tweenTo = 0

local function StopTween() tweenActive = false end
local function StartTween(fromMix, toMix)
  tweenActive = true
  tweenStart = GetTime()
  tweenFrom = fromMix
  tweenTo = toMix
end

local function IsSpinnerShown()
  return (gcdSpinnerNormal and gcdSpinnerNormal:IsShown())
      or (gcdSpinnerSmall  and gcdSpinnerSmall:IsShown())
end

SetMix = function(mix)
  mix = Clamp(mix, 0, 1)
  currentMix = mix

  local spinnerShown  = IsSpinnerShown()
  local spinnerActive = gcdVisualActive or spinnerShown

  SetStyleVisibility()

  local neon = IsNeonStyle()

  if neon then
    -- Flat ring must NEVER contribute in neon mode
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(0)
  end

  if spinnerActive  then
    -- Neon mode: flat ring never contributes
    if neon then
      ringTexNormal:SetAlpha(0)
      ringTexSmall:SetAlpha(0)
    end

    -- If spinner should replace visuals:
    if spinnerActive  then
      -- crossfade spinners
      if gcdSpinnerNormal then gcdSpinnerNormal:SetAlpha(1 - mix) end
      if gcdSpinnerSmall  then gcdSpinnerSmall:SetAlpha(mix) end

      -- Flat mode: spinner replaces ring, so NEVER allow normal fade to run
      if (not neon) and suppressFlatRing then
        ringTexNormal:SetAlpha(0)
        ringTexSmall:SetAlpha(0)
        return
      end
      -- Neon mode falls through so neon layers can still fade normally
    end
  end

  -- Normal crossfade (ring visuals)
  if mix <= 0.0001 then
    if neon then
      neonOuterNormal:SetAlpha(NEON_ALPHA_OUTER); neonOuterSmall:SetAlpha(0)
      neonInnerNormal:SetAlpha(NEON_ALPHA_INNER); neonInnerSmall:SetAlpha(0)
      neonCoreNormal:SetAlpha(NEON_ALPHA_CORE);   neonCoreSmall:SetAlpha(0)
    else
      ringTexNormal:SetAlpha(1)
      ringTexSmall:SetAlpha(0)
    end

  elseif mix >= 0.9999 then
    if neon then
      neonOuterNormal:SetAlpha(0); neonOuterSmall:SetAlpha(NEON_ALPHA_OUTER)
      neonInnerNormal:SetAlpha(0); neonInnerSmall:SetAlpha(NEON_ALPHA_INNER)
      neonCoreNormal:SetAlpha(0);  neonCoreSmall:SetAlpha(NEON_ALPHA_CORE)
    else
      ringTexNormal:SetAlpha(0)
      ringTexSmall:SetAlpha(1)
    end

  else
    if neon then
      local aN = 1 - mix
      local aS = mix
      neonOuterNormal:SetAlpha(aN * NEON_ALPHA_OUTER); neonOuterSmall:SetAlpha(aS * NEON_ALPHA_OUTER)
      neonInnerNormal:SetAlpha(aN * NEON_ALPHA_INNER); neonInnerSmall:SetAlpha(aS * NEON_ALPHA_INNER)
      neonCoreNormal:SetAlpha(aN * NEON_ALPHA_CORE);   neonCoreSmall:SetAlpha(aS * NEON_ALPHA_CORE)
    else
      ringTexNormal:SetAlpha(1 - mix)
      ringTexSmall:SetAlpha(mix)
    end
  end
end

WantsSmallRing = function()
  if not HelloCursorDB.reactiveCursor then return false end
  return (IsMouselooking and IsMouselooking()) and true or false
end

local function SnapToTargetMix()
  SetMix(WantsSmallRing() and 1 or 0)
end

-- ---------------------------------------------------------------------
-- Cursor anchoring (freeze on mouselook start)
-- ---------------------------------------------------------------------

local lastCursorX, lastCursorY = nil, nil
local wasMouselooking = false
local CURSOR_OFFSET_X = 0
local CURSOR_OFFSET_Y = 0

local function CaptureCursorNow()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  lastCursorX, lastCursorY = (cx / scale), (cy / scale)
end

local function StartPickerCursorDriver()
  if pickerDriver then return end
  pickerDriver = CreateFrame("Frame")
  local acc = 0
  pickerDriver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.01 then return end
    acc = 0
    -- while the picker is open, keep following the actual UI cursor
    if ringFrame:IsShown() then
      CaptureCursorNow()
      if UpdateRingPosition then UpdateRingPosition() end
    end
  end)
end

local function StopPickerCursorDriver()
  if not pickerDriver then return end
  pickerDriver:SetScript("OnUpdate", nil)
  pickerDriver = nil
end

UpdateRingPosition = function()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local mouselooking = (IsMouselooking and IsMouselooking()) and true or false

  if not mouselooking then
    lastCursorX, lastCursorY = cx, cy
  elseif not wasMouselooking then
    if not lastCursorX or not lastCursorY then
      lastCursorX, lastCursorY = cx, cy
    end
  end

  wasMouselooking = mouselooking

  local x = (lastCursorX or cx) + CURSOR_OFFSET_X
  local y = (lastCursorY or cy) + CURSOR_OFFSET_Y

  ringFrame:ClearAllPoints()
  ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- Capture cursor before mouselook clamps it
if WorldFrame and WorldFrame.HookScript then
  WorldFrame:HookScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      CaptureCursorNow()
    end
  end)
end

-- ---------------------------------------------------------------------
-- Visual refresh helpers
-- ---------------------------------------------------------------------

local function RefreshSize()
  local size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)
  HelloCursorDB.size = size

  ringFrame:SetSize(RING_CANVAS_SIZE, RING_CANVAS_SIZE)

  local key = NearestKey(RING_TEX_BY_SIZE, size) or 96

  -- Always keep spinner swipe textures correct (depends on current style)
  do
    local neon = IsNeonStyle()
    local swipeNormal = neon and NEON_CORE_TEX_BY_SIZE[key] or RING_TEX_BY_SIZE[key]
    local swipeSmall  = neon
      and (NEON_CORE_SMALL_TEX_BY_SIZE[key] or NEON_CORE_TEX_BY_SIZE[key])
      or  (RING_SMALL_TEX_BY_SIZE[key] or RING_TEX_BY_SIZE[key])

    if gcdSpinnerNormal and gcdSpinnerNormal.SetSwipeTexture then
      gcdSpinnerNormal:SetSwipeTexture(swipeNormal)
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetSwipeTexture then
      gcdSpinnerSmall:SetSwipeTexture(swipeSmall)
    end
  end

  -- ✅ Always update BOTH styles so toggling neon on/off keeps the same size

  -- Flat ring
  SafeSetTexture(ringTexNormal, RING_TEX_BY_SIZE[key], RING_TEX_BY_SIZE[96])
  SafeSetTexture(ringTexSmall,  RING_SMALL_TEX_BY_SIZE[key], RING_SMALL_TEX_BY_SIZE[96])

  -- Neon
  SafeSetTexture(neonCoreNormal,  NEON_CORE_TEX_BY_SIZE[key],  NEON_CORE_TEX_BY_SIZE[96])
  SafeSetTexture(neonCoreSmall,   NEON_CORE_SMALL_TEX_BY_SIZE[key], NEON_CORE_SMALL_TEX_BY_SIZE[96])

  SafeSetTexture(neonInnerNormal, NEON_INNER_TEX_BY_SIZE[key], NEON_INNER_TEX_BY_SIZE[96])
  SafeSetTexture(neonInnerSmall,  NEON_INNER_SMALL_TEX_BY_SIZE[key], NEON_INNER_SMALL_TEX_BY_SIZE[96])

  SafeSetTexture(neonOuterNormal, NEON_OUTER_TEX_BY_SIZE[key], NEON_OUTER_TEX_BY_SIZE[96])
  SafeSetTexture(neonOuterSmall,  NEON_OUTER_SMALL_TEX_BY_SIZE[key], NEON_OUTER_SMALL_TEX_BY_SIZE[96])

  lastTexKey = key

  SetStyleVisibility()
  ApplyTintIfNeeded(true)

  if SetMix then
    SetMix(currentMix)
  end
end

local function RefreshVisualsImmediate()
  StopTween()
  RefreshSize()
  SetStyleVisibility()
  ApplyTintIfNeeded(true)
  SnapToTargetMix()
end

local function UpdateVisibility()
  local shouldShow = ShouldShowRing()

  if shouldShow then
    local wasShown = ringFrame:IsShown()

    if (IsMouselooking and IsMouselooking()) and (not lastCursorX or not lastCursorY) then
      CaptureCursorNow()
    end

    ringFrame:Show()

    -- If the ring has just become visible (for example when entering
    -- combat while a GCD is already in progress), snap the mix state
    -- to the current mouselook mode and immediately refresh the GCD
    -- spinner. This prevents a frame where both the large and small
    -- GCD spinners are fully visible at once.
    if not wasShown then
      SnapToTargetMix()
      if HelloCursorDB.showGCDSpinner then
        gcdCheckAccum = 0
        CheckGCDPop()
      end
    end

  else
    ringFrame:Hide()
  end
end

-- Always-on driver (lightweight) to react to menu open/close without relying on events.
-- Optimised: only does work when the addon is enabled AND when menu state actually changes.
local visibilityDriver = CreateFrame("Frame")
local visElapsed = 0
local lastMenuOpen = nil
local lastShouldShow = nil

visibilityDriver:SetScript("OnUpdate", function(_, elapsed)
  -- If the addon is off, do nothing.
  if not IsAddonEnabled() then
    if lastShouldShow ~= false then
      lastShouldShow = false
      if ringFrame:IsShown() then ringFrame:Hide() end
    end
    return
  end

  -- If we aren't hiding in menus, there is no reason to poll menus.
  if not HelloCursorDB.hideInMenus then
    -- Still ensure visibility rules are respected if something else changed.
    -- (Very cheap because ShouldShowRing() early-outs fast.)
    if lastShouldShow == nil then
      UpdateVisibility()
      lastShouldShow = ringFrame:IsShown()
    end
    return
  end

  visElapsed = visElapsed + (elapsed or 0)
  if visElapsed < 0.10 then return end -- 10Hz is plenty for menu open/close
  visElapsed = 0

  local menuOpen = IsAnyMenuOpen()

  -- Only recompute visibility if menu state flipped (open/close),
  -- or if we don't have a baseline yet.
  if lastMenuOpen == nil or menuOpen ~= lastMenuOpen then
    lastMenuOpen = menuOpen
    UpdateVisibility()
    lastShouldShow = ringFrame:IsShown()
  end
end)

-- ---------------------------------------------------------------------
-- OnUpdate loop
-- ---------------------------------------------------------------------

local lastTargetMix = 0

ringFrame:SetScript("OnUpdate", function(_, elapsed)
  if not ringFrame:IsShown() then return end

  local targetMix = WantsSmallRing() and 1 or 0
  if targetMix ~= lastTargetMix then
    lastTargetMix = targetMix
    if HelloCursorDB.showGCDSpinner then
      CheckGCDPop() -- sync flags immediately on RMB toggle
    end
  end

  if HelloCursorDB.showGCDSpinner then
    gcdCheckAccum = gcdCheckAccum + (elapsed or 0)
    if gcdCheckAccum >= GCD_POP_CHECK_INTERVAL then
      gcdCheckAccum = 0
      CheckGCDPop()
    end
  end

  local targetMix = WantsSmallRing() and 1 or 0
  if tweenActive then
    local t = (GetTime() - tweenStart) / TWEEN_DURATION
    if t >= 1 then
      StopTween()
      SetMix(tweenTo)
    else
      SetMix(Lerp(tweenFrom, tweenTo, EaseInOut(t)))
    end
  else
    if math_abs(currentMix - targetMix) > 0.001 then
      StartTween(currentMix, targetMix)
    end
  end

  if UpdateRingPosition then UpdateRingPosition() end
end)

-- ---------------------------------------------------------------------
-- Settings UI (Blizzard Settings panel)
-- ---------------------------------------------------------------------

local hexEditBox
local pickBtnRef
local cbClassRef

local cbWorldRef, cbPvERef, cbPvPRef, cbCombatRef, cbReactiveRef
local cbGCDRef, cbHideMenusRef

local sizeSliderRef

local function GetPickerWidget()
  if not ColorPickerFrame then return nil end
  if ColorPickerFrame.GetColorRGB and ColorPickerFrame.SetColorRGB then
    return ColorPickerFrame
  end
  if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
    and ColorPickerFrame.Content.ColorPicker.GetColorRGB
    and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
    return ColorPickerFrame.Content.ColorPicker
  end
  return nil
end

local function RefreshColourUIEnabledState()
  local enabled = not HelloCursorDB.useClassColor
  if pickBtnRef then pickBtnRef:SetEnabled(enabled) end
  if hexEditBox then
    hexEditBox:SetEnabled(enabled)
    hexEditBox:SetAlpha(enabled and 1 or 0.5)
  end
end

local function RefreshOptionsUI()
  if cbWorldRef then cbWorldRef:SetChecked(HelloCursorDB.showWorld and true or false) end
  if cbPvERef then cbPvERef:SetChecked(HelloCursorDB.showPvE and true or false) end
  if cbPvPRef then cbPvPRef:SetChecked(HelloCursorDB.showPvP and true or false) end
  if cbCombatRef then cbCombatRef:SetChecked(HelloCursorDB.showInCombat and true or false) end
  if cbReactiveRef then cbReactiveRef:SetChecked(HelloCursorDB.reactiveCursor and true or false) end
  if cbGCDRef then cbGCDRef:SetChecked(HelloCursorDB.showGCDSpinner and true or false) end
  if cbHideMenusRef then cbHideMenusRef:SetChecked(HelloCursorDB.hideInMenus and true or false) end
  if cbClassRef then cbClassRef:SetChecked(HelloCursorDB.useClassColor and true or false) end

  if hexEditBox then
    hexEditBox:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
  end

  if sizeSliderRef then
    local v = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)
    local snappedKey = NearestKey(RING_TEX_BY_SIZE, v) or 96
    sizeSliderRef:SetValue(snappedKey)
  end

  RefreshColourUIEnabledState()
end

local function SetColorHex(hex)
  local norm = NormalizeHex(hex)
  if not norm then return end

  HelloCursorDB.colorHex = norm
  HelloCursorDB["HelloCursor_colorHex"] = norm -- ✅ keep Settings-backed value in sync

  ApplyTintIfNeeded(true)
  if hexEditBox then hexEditBox:SetText(norm) end
end

local function OpenColorPicker()
  if HelloCursorDB.useClassColor then return end

  local picker = GetPickerWidget()
  if not picker then
    print("HelloCursor: Color picker not available on this client.")
    return
  end

  local r, g, b = HexToRGBA(HelloCursorDB.colorHex)
  local prevHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex

  local function ApplyFromPicker()
    local nr, ng, nb = picker:GetColorRGB()
    SetColorHex(RGBAtoHex(nr, ng, nb))
  end

  local function CancelToPrev()
    SetColorHex(prevHex)
  end

  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.opacity = 0
  ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = 0 }

  ColorPickerFrame.swatchFunc = ApplyFromPicker
  ColorPickerFrame.func = ApplyFromPicker
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.cancelFunc = CancelToPrev

  picker:SetColorRGB(r, g, b)

  -- While picking a colour, show the ring even if menus are open
  forceShowWhilePickingColour = true
  CaptureCursorNow()
  UpdateVisibility()
  StartPickerCursorDriver()

  -- Turn the override off when the picker closes (hook once)
  if not ColorPickerFrame.__HelloCursorHooked then
    ColorPickerFrame.__HelloCursorHooked = true
    ColorPickerFrame:HookScript("OnHide", function()
      forceShowWhilePickingColour = false
      StopPickerCursorDriver()
      UpdateVisibility()
    end)
  end

  ColorPickerFrame:Show()
end

local function ResetToDefaults()
  for k, v in pairs(DEFAULTS) do
    HelloCursorDB[k] = v
  end

  HelloCursorDB.colorHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
  HelloCursorDB.size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)

  -- Keep Settings-backed (namespaced) variables in sync so the Blizzard
  -- Settings controls match defaults on reload.
  local tracked = {
    "enabled",
    "showWorld",
    "showPvE",
    "showPvP",
    "showInCombat",
    "reactiveCursor",
    "showGCDSpinner",
    "hideInMenus",
    "size",
    "useClassColor",
    "colorHex",
    "useNeonRing",
  }

  for _, key in ipairs(tracked) do
    local nsKey = "HelloCursor_" .. key
    if HelloCursorDB[key] ~= nil then
      HelloCursorDB[nsKey] = HelloCursorDB[key]
    end
  end

  RefreshVisualsImmediate()
  UpdateVisibility()
  RefreshOptionsUI()
end

-- Legacy canvas-style panel. On modern clients this is registered as an
-- "advanced" sub-category underneath the vertical layout category so we
-- can keep the richer colour + utilities UI. When used as a top-level
-- category (older clients), it also shows the full set of toggles.
local function CreateSettingsPanelLegacy(parentCategory, isAdvanced)
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end

  local panel = CreateFrame("Frame")
  panel.name = "Hello Cursor"

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  local content = CreateFrame("Frame", nil, scrollFrame)
  scrollFrame:SetScrollChild(content)

  content:SetSize(560, 1)
  content:SetPoint("TOPLEFT", 0, 0)
  content:SetPoint("TOPRIGHT", 0, 0)

  local function UpdateContentHeight(lastWidget, bottomPadding)
    bottomPadding = bottomPadding or 24
    if not lastWidget then
      content:SetHeight(1)
      return
    end

    local top = content:GetTop()
    local bottom = lastWidget:GetBottom()
    if not top or not bottom then return end

    local h = (top - bottom) + bottomPadding
    if h < 1 then h = 1 end
    content:SetHeight(h)
  end

  local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(isAdvanced and "Advanced" or "Hello Cursor")

  if isAdvanced then
    title:SetFontObject("GameFontHighlightLarge") -- white
  end

  local function MakeHeader(text, anchor, yOff)
    local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    h:SetText(text)
    return h
  end

  local function MakeCheckbox(label, get, set, anchor, yOff, onChange)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)

    if cb.Text then
      cb.Text:SetText(label)
    else
      local t = _G[cb:GetName() .. "Text"]
      if t then t:SetText(label) end
    end

    cb:SetScript("OnShow", function()
      cb:SetChecked(get() and true or false)
    end)

    cb:SetScript("OnClick", function(self)
      set(self:GetChecked() and true or false)
      if onChange then onChange() end
      UpdateVisibility()
    end)

    return cb
  end

  local function MakeSeparator(anchor, yOff)
    local sep = content:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -16, yOff)
    sep:SetSize(560, 1)
    sep:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    return sep
  end

  local previousAnchor = title

  if not isAdvanced then
    -- Visibility
    local visHeader = MakeHeader("Visibility", title, -18)

    cbWorldRef = MakeCheckbox(
      "Show in world",
      function() return HelloCursorDB.showWorld end,
      function(v) HelloCursorDB.showWorld = v end,
      visHeader, -10
    )

    cbPvERef = MakeCheckbox(
      "Show in dungeons / delves / raids",
      function() return HelloCursorDB.showPvE end,
      function(v) HelloCursorDB.showPvE = v end,
      cbWorldRef, -10
    )

    cbPvPRef = MakeCheckbox(
      "Show in battlegrounds / arena",
      function() return HelloCursorDB.showPvP end,
      function(v) HelloCursorDB.showPvP = v end,
      cbPvERef, -10
    )

    cbCombatRef = MakeCheckbox(
      "Show in combat",
      function() return HelloCursorDB.showInCombat end,
      function(v) HelloCursorDB.showInCombat = v end,
      cbPvPRef, -10
    )

    MakeSeparator(cbCombatRef, -14)

    -- Behaviour
    local behHeader = MakeHeader("Behaviour", cbCombatRef, -26)

    cbReactiveRef = MakeCheckbox(
      "Reactive cursor (shrink while holding RMB)",
      function() return HelloCursorDB.reactiveCursor end,
      function(v) HelloCursorDB.reactiveCursor = v end,
      behHeader, -10,
      function()
        StopTween()
        SnapToTargetMix()
      end
    )

    cbGCDRef = MakeCheckbox(
      "Global cooldown (GCD) animation",
      function() return HelloCursorDB.showGCDSpinner end,
      function(v) HelloCursorDB.showGCDSpinner = v end,
      cbReactiveRef, -10,
      function()
        ApplyTintIfNeeded(true)
      end
    )

    cbHideMenusRef = MakeCheckbox(
      "Hide ring while game menus are open",
      function() return HelloCursorDB.hideInMenus end,
      function(v) HelloCursorDB.hideInMenus = v end,
      cbGCDRef, -10,
      function()
        UpdateVisibility()
      end
    )

    MakeSeparator(cbHideMenusRef, -14)

    -- Appearance (basic)
    local appearanceHeader = MakeHeader("Appearance", cbHideMenusRef, -26)

    local sizeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 0, -12)
    sizeLabel:SetText("Ring size")

    sizeSliderRef = CreateFrame("Slider", "HelloCursorSizeSlider", content, "OptionsSliderTemplate")
    sizeSliderRef:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -8)
    sizeSliderRef:SetWidth(260)
    sizeSliderRef:SetMinMaxValues(64, 128)
    sizeSliderRef:SetValueStep(16)
    sizeSliderRef:SetObeyStepOnDrag(true)

    do
      local sliderName = sizeSliderRef:GetName()
      if sliderName then
        local low  = _G[sliderName .. "Low"]
        local high = _G[sliderName .. "High"]
        local text = _G[sliderName .. "Text"]
        if low  then low:SetText("64") end
        if high then high:SetText("128") end
        if text then text:SetText("") end
      end
    end

    local sliderLock = false
    sizeSliderRef:SetScript("OnValueChanged", function(self, value)
      if sliderLock then return end

      value = tonumber(value) or DEFAULTS.size
      local snappedKey = NearestKey(RING_TEX_BY_SIZE, value) or 96

      sliderLock = true
      self:SetValue(snappedKey)
      sliderLock = false

      HelloCursorDB.size = snappedKey

      RefreshSize()
      UpdateRingPosition()
    end)

    cbClassRef = MakeCheckbox(
      "Use class colour",
      function() return HelloCursorDB.useClassColor end,
      function(v) HelloCursorDB.useClassColor = v end,
      sizeSliderRef, -16,
      function()
        ApplyTintIfNeeded(true)
        RefreshColourUIEnabledState()
      end
    )

    previousAnchor = cbClassRef
  end

  local colorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", previousAnchor, "BOTTOMLEFT", 0, -22)
  colorLabel:SetText("Ring colour")

  pickBtnRef = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  pickBtnRef:SetSize(120, 22)
  pickBtnRef:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
  pickBtnRef:SetText("Pick colour...")
  pickBtnRef:SetScript("OnClick", OpenColorPicker)

  local hexLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hexLabel:SetPoint("LEFT", pickBtnRef, "RIGHT", 10, 0)
  hexLabel:SetText("Hex")

  hexEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  hexEditBox:SetSize(110, 22)
  hexEditBox:SetPoint("LEFT", hexLabel, "RIGHT", 8, 0)
  hexEditBox:SetAutoFocus(false)

  hexEditBox:SetScript("OnShow", function(self)
    self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    RefreshColourUIEnabledState()
  end)

  hexEditBox:SetScript("OnEnterPressed", function(self)
    if HelloCursorDB.useClassColor then
      self:ClearFocus()
      return
    end

    local typed = self:GetText()
    local norm = NormalizeHex(typed)
    if norm then
      SetColorHex(norm)
    else
      self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    end
    self:ClearFocus()
  end)

  hexEditBox:SetScript("OnEscapePressed", function(self)
    self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    self:ClearFocus()
  end)

  local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", pickBtnRef, "BOTTOMLEFT", 0, -6)
  hint:SetText("Use RRGGBB (example: FF4FD8). Class colour disables picker & hex.")
  hint:SetTextColor(0.75, 0.75, 0.75)

  panel:HookScript("OnShow", function()
    RefreshOptionsUI()
    C_Timer.After(0, function()
      if hint and hint.GetBottom then
        UpdateContentHeight(hint, 28)
      end
    end)
  end)

  local category
  if parentCategory and Settings.RegisterCanvasLayoutSubcategory and isAdvanced then
    category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, "Advanced")
  else
    category = Settings.RegisterCanvasLayoutCategory(panel, "Hello Cursor")
    Settings.RegisterAddOnCategory(category)
  end

  RefreshOptionsUI()
  return category
end

local settingsCategory = nil

local function CreateSettingsPanel()
  if settingsCategory then return settingsCategory end
  if not Settings then
    settingsCategory = nil
    return settingsCategory
  end

  -- If the vertical layout APIs aren't available, fall back to the
  -- full legacy canvas panel as the top-level category.
  if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then
    settingsCategory = CreateSettingsPanelLegacy(nil, false)
    return settingsCategory
  end

  local category, layout = Settings.RegisterVerticalLayoutCategory("Hello Cursor")
  settingsCategory = category
  Settings.RegisterAddOnCategory(category)

  local HC_VAR_PREFIX = "HelloCursor_"

  local function VarTypeFor(v)
    if Settings.VarType then
      if type(v) == "boolean" then return Settings.VarType.Boolean end
      if type(v) == "number" then return Settings.VarType.Number end
    end
    return type(v)
  end

  local function RegisterSetting(key, name, defaultValue)
    local varName = HC_VAR_PREFIX .. key

    -- Seed the underlying storage from our existing DB field so the
    -- Settings panel reflects current values instead of always defaulting.
    if HelloCursorDB[varName] == nil then
      if HelloCursorDB[key] ~= nil then
        HelloCursorDB[varName] = HelloCursorDB[key]
      else
        HelloCursorDB[varName] = defaultValue
      end
    end

    local ok, setting = pcall(Settings.RegisterAddOnSetting,
      category,
      varName,     -- variable (must be globally unique)
      varName,     -- variableKey
      HelloCursorDB,
      VarTypeFor(defaultValue),
      name,
      defaultValue
    )
    if ok and setting then return setting end

    error(("HelloCursor: RegisterAddOnSetting failed for %s (%s): %s"):format(key, tostring(varName), tostring(setting)))
  end

  local function OnChangedFor(key, setting)
    if not (Settings.SetOnValueChangedCallback and setting and setting.GetValue) then return end

    local varName = HC_VAR_PREFIX .. key

    -- Guard against re-entrant callbacks (Reset to defaults can cause cascades)
    local inCallback = false

    Settings.SetOnValueChangedCallback(varName, function()
      if inCallback then return end
      inCallback = true

      local value = setting:GetValue()

      -- keep both in sync
      HelloCursorDB[varName] = value
      HelloCursorDB[key] = value

      if key == "size" then
        -- Snap our stored value, but DO NOT call setting:SetValue() here
        -- (that can recurse during "Reset to defaults" and blow the stack).
        local v = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)
        local snappedKey = NearestKey(RING_TEX_BY_SIZE, v) or 96

        HelloCursorDB.size = snappedKey
        HelloCursorDB[varName] = snappedKey

        RefreshSize()
        UpdateRingPosition()

      elseif key == "useClassColor" or key == "colorHex" then
        ApplyTintIfNeeded(true)
        RefreshColourUIEnabledState()

      elseif key == "reactiveCursor" then
        StopTween()
        SnapToTargetMix()

      elseif key == "showGCDSpinner" then
        ApplyTintIfNeeded(true)
        if not HelloCursorDB.showGCDSpinner then
          if gcdSpinnerNormal then gcdSpinnerNormal:Hide() end
          if gcdSpinnerSmall then gcdSpinnerSmall:Hide() end
          gcdVisualActive = false
          suppressFlatRing = false
          if SetMix then SetMix(currentMix) end
        end
        
      elseif key == "useNeonRing" then
        RefreshSize()
        ApplyTintIfNeeded(true)
        StopTween()
        SnapToTargetMix()

      elseif key == "showWorld"
        or key == "showPvE"
        or key == "showPvP"
        or key == "showInCombat"
        or key == "hideInMenus"
        or key == "enabled" then

        lastMenuOpen = nil
        lastShouldShow = nil
        UpdateVisibility()
      end

      inCallback = false
    end)
  end

  -- Register colorHex so the Blizzard "Defaults" button resets it too,
  -- but we don't create a visible control in the main list.
  do
    local settingColorHex = RegisterSetting("colorHex", "Ring colour (hex)", DEFAULTS.colorHex)
    OnChangedFor("colorHex", settingColorHex)
  end

  local function CreateCheckboxControl(setting, tooltip)
    if Settings.CreateCheckbox then
      return Settings.CreateCheckbox(category, setting, tooltip)
    end
    if Settings.CreateCheckBox then
      return Settings.CreateCheckBox(category, setting, tooltip)
    end
  end

  local function AddCheckbox(key, name, tooltip)
    local defaultValue = DEFAULTS[key]
    if type(defaultValue) ~= "boolean" then
      defaultValue = HelloCursorDB[key] and true or false
    end

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)
    CreateCheckboxControl(setting, tooltip)
    return setting
  end

  local function AddSlider(key, name, tooltip, minValue, maxValue, step)
    local current = HelloCursorDB[key]
    if type(current) ~= "number" then current = DEFAULTS[key] or minValue end
    if current < minValue then current = minValue end
    if current > maxValue then current = maxValue end
    HelloCursorDB[key] = current

    -- ✅ important: use the true default, not the current value
    local setting = RegisterSetting(key, name, DEFAULTS[key] or current)
    OnChangedFor(key, setting)

    if Settings.CreateSliderOptions and Settings.CreateSlider then
      local opts = Settings.CreateSliderOptions(minValue, maxValue, step)
      if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label and MinimalSliderWithSteppersMixin.Label.Right then
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
      end
      Settings.CreateSlider(category, setting, opts, tooltip)
    elseif Settings.CreateSlider then
      Settings.CreateSlider(category, setting, minValue, maxValue, step, tooltip)
    end

    return setting
  end

  local function AddHeader(text)
    if layout and type(layout.AddInitializer) == "function"
      and type(CreateSettingsListSectionHeaderInitializer) == "function" then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  AddCheckbox(
    "enabled",
    "Enable Hello Cursor",
    "Enables or disables Hello Cursor.\n\nChanges require a UI reload."
  )

  AddCheckbox(
    "showWorld",
    "Show in world",
    "Show the cursor ring in open world zones."
  )

  AddCheckbox(
    "showPvE",
    "Show in dungeons / delves / raids",
    "Show the cursor ring in 5-player dungeons, delves, and raids."
  )

  AddCheckbox(
    "showPvP",
    "Show in battlegrounds / arena",
    "Show the cursor ring in battlegrounds and arenas."
  )

  AddCheckbox(
    "showInCombat",
    "Show in combat",
    "Always show the cursor ring while you are in combat, regardless of location."
  )

  AddCheckbox(
    "hideInMenus",
    "Hide ring while game menus are open",
    "Hide the cursor ring while the main game menus are visible."
  )

  AddCheckbox(
    "reactiveCursor",
    "Reactive cursor",
    "Shrinks the cursor ring while holding right mouse."
  )

  AddCheckbox(
    "showGCDSpinner",
    "Global cooldown (GCD) animation",
    "Show a subtle animation on the ring that tracks the global cooldown."
  )

  AddHeader("Appearance")

  AddSlider(
    "size",
    "Ring size",
    "Adjust the overall size of the cursor ring.",
    64, 128, 16
  )

  AddCheckbox(
    "useClassColor",
    "Use class colour",
    "Tint the ring using your class colour instead of a custom colour.\n\nRing colour (hex & picker) is configured in Advanced settings."
  )

  AddCheckbox(
    "useNeonRing",
    "Neon ring style",
    "Replaces the standard ring with a neon-style ring that includes a glowing core."
  )

  -- Advanced canvas-style subcategory (colour hex + utilities, legacy layout)
  CreateSettingsPanelLegacy(category, true)

  return settingsCategory
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    HelloCursorDB = CopyDefaults(HelloCursorDB, DEFAULTS)
    HelloCursorDB.colorHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
    HelloCursorDB.size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)

    CaptureCursorNow()

    RefreshVisualsImmediate()
    UpdateVisibility()

    if not settingsCategory then
      settingsCategory = CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")
    return
  end

  ApplyTintIfNeeded(false)
  UpdateVisibility()
end)

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------

SLASH_HELLOCURSOR1 = "/hc"
SLASH_HELLOCURSOR2 = "/hellocursor"

SlashCmdList.HELLOCURSOR = function(msg)
  if msg == "toggle" then
    local nsKey = "HelloCursor_enabled"
    local current = IsAddonEnabled()
    local newValue = not current
    HelloCursorDB.enabled = newValue
    HelloCursorDB[nsKey] = newValue
    UpdateVisibility()
    print(("HelloCursor: %s"):format(HelloCursorDB.enabled and "enabled" or "disabled"))
    return
  end

  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory:GetID())
  end
end
