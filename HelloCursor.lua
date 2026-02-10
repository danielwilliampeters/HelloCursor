-- Hello Cursor: cursor ring addon (Retail)

local ADDON_NAME = ...
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

HelloCursorDB = HelloCursorDB or {}

HelloCursor = HelloCursor or {}
local HC = HelloCursor
HC.ADDON_NAME = ADDON_NAME
HC.VERSION = VERSION

-- ---------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------

local DEFAULTS = {
  enabled = true,
  colorHex = "FF4FD8",
  useClassColor = false,
  size = 80,
  showWorld = true,
  showHousing = false,
  showPvE = true,
  showPvP = true,
  showInCombat = true,
  hideInMenus = true,
  -- Mouselook behaviour while holding RMB
  -- "none"        = no special behaviour
  -- "show"        = force ring visible while mouselooking
  -- "shrink"      = shrink ring while mouselooking
  -- "show_shrink" = force visible + shrink while mouselooking
  mouselookMode = "show_shrink",
  showGCDSpinner = true,
  classicRingStyle = false,
}

local function SyncRingStyleFlags()
  -- Ensure classicRingStyle is boolean; default is false (neon)
  if HelloCursorDB.classicRingStyle == nil then
    -- If legacy value exists, map it ONCE:
    -- useNeonRing=true => classicRingStyle=false
    -- useNeonRing=false => classicRingStyle=true
    if HelloCursorDB.useNeonRing ~= nil then
      HelloCursorDB.classicRingStyle = (HelloCursorDB.useNeonRing == false)
    else
      HelloCursorDB.classicRingStyle = false
    end
  end
  HelloCursorDB.classicRingStyle = HelloCursorDB.classicRingStyle and true or false
  HelloCursorDB.useNeonRing = not HelloCursorDB.classicRingStyle
  -- Keep Settings-backed vars in sync if they exist:
  HelloCursorDB["HelloCursor_classicRingStyle"] = HelloCursorDB.classicRingStyle
  HelloCursorDB["HelloCursor_useNeonRing"] = HelloCursorDB.useNeonRing
end

-- ---------------------------------------------------------------------
-- Mouselook behaviour (RMB) helpers
-- ---------------------------------------------------------------------

local VALID_MOUSELOOK_MODES = {
  none        = true,
  show        = true,
  shrink      = true,
  show_shrink = true,
}

local function NormalizeMouselookMode(mode)
  if type(mode) ~= "string" then
    return DEFAULTS.mouselookMode or "none"
  end
  mode = mode:lower()
  if VALID_MOUSELOOK_MODES[mode] then
    return mode
  end
  return DEFAULTS.mouselookMode or "none"
end

local function SyncMouselookModeFromLegacy()
  local mode = HelloCursorDB.mouselookMode

  if not VALID_MOUSELOOK_MODES[mode] then
    local reactive = HelloCursorDB.reactiveCursor
    local reactiveNS = HelloCursorDB["HelloCursor_reactiveCursor"]
    if reactive == nil and type(reactiveNS) == "boolean" then
      reactive = reactiveNS
    end

    local showML = HelloCursorDB.showWhileMouselooking
    local showMLNS = HelloCursorDB["HelloCursor_showWhileMouselooking"]
    if showML == nil and type(showMLNS) == "boolean" then
      showML = showMLNS
    end

    if reactive == nil and showML == nil then
      mode = DEFAULTS.mouselookMode or "none"
    else
      reactive = reactive and true or false
      showML = showML and true or false

      if reactive and showML then
        mode = "show_shrink"
      elseif reactive then
        mode = "shrink"
      elseif showML then
        mode = "show"
      else
        mode = "none"
      end
    end
  end

  mode = NormalizeMouselookMode(mode)

  HelloCursorDB.mouselookMode = mode
  HelloCursorDB["HelloCursor_mouselookMode"] = mode

  -- Keep legacy booleans in sync for any external readers, but the
  -- addon logic itself derives behaviour from mouselookMode.
  local reactive = (mode == "shrink" or mode == "show_shrink")
  local showML = (mode == "show" or mode == "show_shrink")

  HelloCursorDB.reactiveCursor = reactive
  HelloCursorDB.showWhileMouselooking = showML

  HelloCursorDB["HelloCursor_reactiveCursor"] = reactive
  HelloCursorDB["HelloCursor_showWhileMouselooking"] = showML
end

local function IsMouselookShowEnabled()
  return HelloCursorDB.mouselookMode == "show"
      or HelloCursorDB.mouselookMode == "show_shrink"
end

local function IsMouselookShrinkEnabled()
  return HelloCursorDB.mouselookMode == "shrink"
      or HelloCursorDB.mouselookMode == "show_shrink"
end

-- Seed / migrate mouselook mode once on load.
SyncMouselookModeFromLegacy()

-- ---------------------------------------------------------------------
-- Small utils
-- ---------------------------------------------------------------------

local GetTime             = GetTime
local GetCursorPosition   = GetCursorPosition
local IsMouselooking      = IsMouselooking
local UnitAffectingCombat = UnitAffectingCombat
local IsInInstance        = IsInInstance
local math_abs            = math.abs

local function IsMouselookActive()
  return (IsMouselooking and IsMouselooking()) and true or false
end

local rmbDownAt = 0
local rmbIsDown = false
local RMB_HOLD_THRESHOLD = 0.12

local function IsIntentionalMouselookActive()
  if not IsMouselookActive() then return false end
  if not rmbIsDown then return false end

  local downAt = rmbDownAt or 0
  if downAt <= 0 then return false end

  return (GetTime() - downAt) >= RMB_HOLD_THRESHOLD
end

local NormalizeHex = HC.NormalizeHex or (HC.Util and HC.Util.NormalizeHex)

local function GetNormalizedColorHex()
  return (NormalizeHex and NormalizeHex(HelloCursorDB.colorHex))
    or DEFAULTS.colorHex
end

local VALID_SIZES = {
  [64]  = true,
  [80]  = true,
  [96]  = true,
  [128] = true,
}

local function NearestSupportedSize(n)
  n = tonumber(n)
  if not n then return DEFAULTS.size end

  if VALID_SIZES[n] then return n end

  -- Explicit migration: old "Huge" 192 -> 128
  if n == 192 then return 128 end

  -- Fallback: snap to nearest supported
  if n < 88  then return 80 end
  if n < 112 then return 96 end
  return 128
end

local function GetNormalizedSize()
  local size = NearestSupportedSize(HelloCursorDB.size)

  HelloCursorDB.size = size
  HelloCursorDB["HelloCursor_size"] = size

  return size
end

-- ---------------------------------------------------------------------
-- Visibility rules
-- ---------------------------------------------------------------------

local function IsAnyMenuOpen()
  if GameMenuFrame and GameMenuFrame:IsShown() then return true end

  if SettingsPanel and SettingsPanel:IsShown() then return true end

  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then return true end
  if VideoOptionsFrame and VideoOptionsFrame:IsShown() then return true end
  if AudioOptionsFrame and AudioOptionsFrame:IsShown() then return true end

  return false
end

local function IsInHousingZone()
  if not C_Housing then return false end

  if C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot() then
    return true
  end

  if C_Housing.IsInsideHouse and C_Housing.IsInsideHouse() then
    return true
  end

  if C_Housing.IsOnNeighborhoodMap and C_Housing.IsOnNeighborhoodMap() then
    return true
  end

  return false
end

local function IsAllowedInZone()
  if HelloCursorDB.showInCombat and UnitAffectingCombat("player") then
    return true
  end

  if IsInHousingZone() then
    return HelloCursorDB.showHousing ~= false
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

local function SetForceShowWhilePickingColour(flag)
  forceShowWhilePickingColour = flag and true or false
end

local function ShouldShowRing()
  if not IsAddonEnabled() then
    return false
  end

  -- While the colour picker is open, force the ring to be visible
  -- regardless of per-zone / menu visibility settings.
  if forceShowWhilePickingColour then
    return true
  end

  if HelloCursorDB.hideInMenus and IsAnyMenuOpen() then
    return false
  end

  -- Optional override: always show the ring while mouselooking,
  -- even if the current zone would normally hide it. This still
  -- respects the "hide in menus" rule above.
  if IsMouselookShowEnabled() and IsIntentionalMouselookActive() then
    return true
  end

  return IsAllowedInZone()
end

-- ---------------------------------------------------------------------
-- Frame + textures
-- ---------------------------------------------------------------------

local ringFrame = CreateFrame("Frame", "HelloCursorFrame", UIParent)
ringFrame:SetFrameStrata("TOOLTIP")
ringFrame:SetSize(HC.TUNE.RING_CANVAS_SIZE, HC.TUNE.RING_CANVAS_SIZE)
ringFrame:Hide()

-- =========================================================
-- BASE RING (bottom of stack)
-- =========================================================
local ringTexNormal = ringFrame:CreateTexture(nil, "BACKGROUND")
local ringTexSmall  = ringFrame:CreateTexture(nil, "BACKGROUND")

ringTexNormal:SetAllPoints(true)
ringTexSmall:SetAllPoints(true)

-- =========================================================
-- NEON EDGE (ring edge highlight)
-- =========================================================
local neonEdgeNormal = ringFrame:CreateTexture(nil, "OVERLAY")
local neonEdgeSmall  = ringFrame:CreateTexture(nil, "OVERLAY")

neonEdgeNormal:SetAllPoints(true)
neonEdgeSmall:SetAllPoints(true)

neonEdgeNormal:SetBlendMode("ADD")
neonEdgeSmall:SetBlendMode("ADD")

-- =========================================================
-- NEON INNER (top highlight)
-- =========================================================
local neonInnerNormal = ringFrame:CreateTexture(nil, "OVERLAY")
local neonInnerSmall  = ringFrame:CreateTexture(nil, "OVERLAY")

neonInnerNormal:SetAllPoints(true)
neonInnerSmall:SetAllPoints(true)

neonInnerNormal:SetBlendMode("ADD")
neonInnerSmall:SetBlendMode("ADD")

-- =========================================================
-- NEON CORE (above base)
-- =========================================================
local neonCoreNormal = ringFrame:CreateTexture(nil, "ARTWORK")
local neonCoreSmall  = ringFrame:CreateTexture(nil, "ARTWORK")

neonCoreNormal:SetAllPoints(true)
neonCoreSmall:SetAllPoints(true)

neonCoreNormal:SetBlendMode("ADD")
neonCoreSmall:SetBlendMode("ADD")

-- =========================================================
-- Initial textures (overridden by RefreshSize)
-- =========================================================
if HC.TEX and HC.Util and HC.Util.SafeSetTexture then
  HC.Util.SafeSetTexture(ringTexNormal, HC.TEX.RING[96], nil)
  HC.Util.SafeSetTexture(ringTexSmall,  HC.TEX.RING_SMALL[96], HC.TEX.RING[96])

  HC.Util.SafeSetTexture(neonCoreNormal,  HC.TEX.NEON_CORE[96], nil)
  HC.Util.SafeSetTexture(neonCoreSmall,   HC.TEX.NEON_CORE_SMALL[96], HC.TEX.NEON_CORE[96])

  HC.Util.SafeSetTexture(neonInnerNormal, HC.TEX.NEON_INNER[96], nil)
  HC.Util.SafeSetTexture(neonInnerSmall,  HC.TEX.NEON_INNER_SMALL[96], HC.TEX.NEON_INNER[96])

  HC.Util.SafeSetTexture(neonEdgeNormal, HC.TEX.NEON_EDGE[96], nil)
  HC.Util.SafeSetTexture(neonEdgeSmall,  HC.TEX.NEON_EDGE_SMALL[96], HC.TEX.NEON_EDGE[96])
end

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
if gcdSpinnerNormal.SetSwipeTexture and HC.TEX then
  gcdSpinnerNormal:SetSwipeTexture(HC.TEX.RING[96])
end
if gcdSpinnerSmall.SetSwipeTexture and HC.TEX then
  gcdSpinnerSmall:SetSwipeTexture(HC.TEX.RING_SMALL[96] or HC.TEX.RING[96])
end

local function HideGCDSpinners()
  if gcdSpinnerNormal then gcdSpinnerNormal:Hide() end
  if gcdSpinnerSmall  then gcdSpinnerSmall:Hide() end
end

local function IsNeonStyle()
  return not (HelloCursorDB.classicRingStyle and true or false)
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
  local showSmall = not forceShowWhilePickingColour

  -- While using the colour picker we completely disable the small
  -- ring textures so only the default ring can ever be shown,
  -- regardless of mix or any other visual state.
  SetShownSafe(ringTexNormal, true)
  SetShownSafe(ringTexSmall,  showSmall)

  SetShownSafe(neonCoreNormal,  neon)
  SetShownSafe(neonCoreSmall,   neon and showSmall)
  SetShownSafe(neonInnerNormal, neon)
  SetShownSafe(neonInnerSmall,  neon and showSmall)
  SetShownSafe(neonEdgeNormal, neon)
  SetShownSafe(neonEdgeSmall,  neon and showSmall)
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

  local r, g, b, a = HC.Util.HexToRGBA(HelloCursorDB.colorHex)
  return r, g, b, a, ("hex:%s"):format(GetNormalizedColorHex())
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

    -- Keep the CORE white so it can actually look white
    neonCoreNormal:SetVertexColor(1, 1, 1, tintA)
    neonCoreSmall:SetVertexColor(1, 1, 1, tintA)

    -- Tint the glow layers with your chosen colour
    neonInnerNormal:SetVertexColor(r, g, b, tintA)
    neonInnerSmall:SetVertexColor(r, g, b, tintA)

    neonEdgeNormal:SetVertexColor(r, g, b, tintA)
    neonEdgeSmall:SetVertexColor(r, g, b, tintA)
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
local gcdVisualActive = false
local gcdPopPlaying = false
local suppressFlatRing = false
local gcdCheckAccum = 0
local neonPulseStrength = 0

local function UpdateNeonPulseStrength(gcdActive, remaining, duration)
    if not HC.TUNE.NEON_GCD_PULSE_ENABLED then
    neonPulseStrength = 0
    return
  end

  if not (HelloCursorDB.showGCDSpinner and IsNeonStyle()) then
    neonPulseStrength = 0
    return
  end

  if gcdActive and duration and duration > 0 then
    if HC.TUNE.NEON_PULSE_USE_GCD_PROGRESS then
      local frac = 1 - HC.Util.Clamp(remaining / duration, 0, 1)
      neonPulseStrength = HC.Util.Clamp(0.35 + 0.65 * frac, 0, 1)
    else
      neonPulseStrength = 1
    end
  else
    neonPulseStrength = 0
  end
end

-- ---------------------------------------------------------------------
-- GCD end pop
-- ---------------------------------------------------------------------

local gcdPopAnim = ringFrame:CreateAnimationGroup()

local popUp = gcdPopAnim:CreateAnimation("Scale")
popUp:SetOrder(1)
popUp:SetScale(HC.TUNE.GCD_POP_SCALE, HC.TUNE.GCD_POP_SCALE)
popUp:SetDuration(HC.TUNE.GCD_POP_UP_TIME)
popUp:SetSmoothing("OUT")

local popDown = gcdPopAnim:CreateAnimation("Scale")
popDown:SetOrder(2)
popDown:SetScale(1, 1)
popDown:SetDuration(HC.TUNE.GCD_POP_DOWN_TIME)
popDown:SetSmoothing("IN")

gcdPopAnim:SetScript("OnPlay", function()
  gcdPopPlaying = true

  -- Pop is a pulse on the RING, so ensure the ring visuals are active.
  gcdVisualActive = false
  suppressFlatRing = false

  HideGCDSpinners()

  if SetMix then SetMix(currentMix) end
end)

gcdPopAnim:SetScript("OnFinished", function()
  gcdPopPlaying = false
end)

gcdPopAnim:SetScript("OnStop", function()
  gcdPopPlaying = false
end)

local function TriggerGCDPop()
  if not HC.TUNE.GCD_POP_ENABLED then return end
  if not ringFrame:IsShown() then return end
  if not HelloCursorDB.showGCDSpinner then return end

  if gcdPopAnim:IsPlaying() then
    gcdPopAnim:Stop()
  end
  gcdPopAnim:Play()
end

local function CheckGCDPop()
  local now = GetTime()
  local startTime, duration, enabled = HC.Util.GetSpellCooldownCompat(HC.TUNE.GCD_SPELL_ID)
  local gcdActive = false
  local remaining = 0

  if enabled ~= 0 and duration and duration > 0 and startTime and startTime > 0 then
    remaining = (startTime + duration) - now
    gcdActive = remaining > 0
  end

  -- Neon-only GCD pulse strength (0-1) based on progress through the GCD.
  UpdateNeonPulseStrength(gcdActive, remaining, duration)

  if lastGCDBusy and (not gcdActive) then
    TriggerGCDPop()
  end

  if lastGCDBusy and gcdActive and (remaining > lastGCDRemaining + 0.02) and (lastGCDRemaining > 0) and (lastGCDRemaining < 0.08) then
    TriggerGCDPop()
  end

  -- Spinner / ring base visibility
  -- In neon style we only want the end-of-GCD pop; the spinner wedge
  -- should remain exclusive to the non-neon (flat) ring.
  local wantSpinner = HelloCursorDB.showGCDSpinner
                    and gcdActive
                    and (not gcdPopPlaying)
                    and (not IsNeonStyle())

  gcdVisualActive = wantSpinner
  suppressFlatRing = wantSpinner

  if wantSpinner then
    -- While the spinner is active, hide the static ring visuals so
    -- the GCD wedge is the only visible ring (this matches the
    -- "base ring" behaviour for both flat and neon styles).
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(0)

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
    HideGCDSpinners()
  end

  gcdVisualActive = wantSpinner
  if not gcdVisualActive and SetMix then
    -- Restore ring visuals according to the current mix
    SetMix(currentMix)
  end

  lastGCDBusy = gcdActive
  lastGCDRemaining = remaining
end

local function ResyncGCDVisualsAfterPicker()
  if HelloCursorDB.showGCDSpinner then
    gcdCheckAccum = 0
    CheckGCDPop()
  end
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
  mix = HC.Util.Clamp(mix, 0, 1)
  currentMix = mix
  HC.currentMix = currentMix

  local spinnerShown  = IsSpinnerShown()
  local spinnerActive = gcdVisualActive or spinnerShown

  SetStyleVisibility()

  local neon = IsNeonStyle()

  if spinnerActive then
    -- crossfade spinners
    if gcdSpinnerNormal then gcdSpinnerNormal:SetAlpha(1 - mix) end
    if gcdSpinnerSmall  then gcdSpinnerSmall:SetAlpha(mix) end

    -- When the spinner is replacing the visuals, hide both the base
    -- ring and (in neon mode) the neon overlays so the behaviour is
    -- identical for flat and neon styles.
    if suppressFlatRing then
      ringTexNormal:SetAlpha(0)
      ringTexSmall:SetAlpha(0)

      if neon then
        neonCoreNormal:SetAlpha(0);  neonCoreSmall:SetAlpha(0)
        neonInnerNormal:SetAlpha(0); neonInnerSmall:SetAlpha(0)
      end
      return
    end
  end

  -- Normal crossfade (BASE ring always)
  local baseMul = 1
  if neon then baseMul = HC.TUNE.NEON_ALPHA_BASE end

  if mix <= 0.0001 then
    ringTexNormal:SetAlpha(1 * baseMul)
    ringTexSmall:SetAlpha(0)
  elseif mix >= 0.9999 then
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(1 * baseMul)
  else
    ringTexNormal:SetAlpha((1 - mix) * baseMul)
    ringTexSmall:SetAlpha(mix * baseMul)
  end

  -- Neon overlays (only when neon style enabled)
  if neon then
    -- GCD-driven neon pulse (core + inner) while GCD is active.
    local pulseStrength = neonPulseStrength or 0

    -- Default (no pulse): your normal steady neon
    local coreBase  = HC.TUNE.NEON_ALPHA_CORE
    local innerBase = HC.TUNE.NEON_ALPHA_INNER
    local edgeBase  = HC.TUNE.NEON_ALPHA_EDGE

    if pulseStrength > 0 then
      -- osc: 0..1
      local osc = 0.5 + 0.5 * math.sin(GetTime() * HC.TUNE.NEON_GCD_PULSE_SPEED * 2 * math.pi)

      -- Wide, obvious swing while pulsing.
      -- We blend between steady neon and pulsing neon using pulseStrength.
      local corePulse  = HC.Util.Lerp(HC.TUNE.NEON_PULSE_CORE_MIN,  HC.TUNE.NEON_PULSE_CORE_MAX,  osc)
      -- local innerPulse = HC.Util.Lerp(HC.TUNE.NEON_PULSE_INNER_MIN, HC.TUNE.NEON_PULSE_INNER_MAX, osc)
      -- local edgePulse = HC.Util.Lerp(HC.TUNE.NEON_PULSE_EDGE_MIN, HC.TUNE.NEON_PULSE_EDGE_MAX, osc)

      coreBase  = HC.Util.Lerp(coreBase,  corePulse,  pulseStrength)
      -- innerBase = HC.Util.Lerp(innerBase, innerPulse, pulseStrength)
      -- edgeBase = HC.Util.Lerp(edgeBase, edgePulse, pulseStrength)
    end

    if mix <= 0.0001 then
      neonCoreNormal:SetAlpha(coreBase);   neonCoreSmall:SetAlpha(0)
      neonInnerNormal:SetAlpha(innerBase); neonInnerSmall:SetAlpha(0)
      neonEdgeNormal:SetAlpha(edgeBase); neonEdgeSmall:SetAlpha(0)
    elseif mix >= 0.9999 then
      neonCoreNormal:SetAlpha(0);  neonCoreSmall:SetAlpha(coreBase)
      neonInnerNormal:SetAlpha(0); neonInnerSmall:SetAlpha(innerBase)
      neonEdgeNormal:SetAlpha(0); neonEdgeSmall:SetAlpha(edgeBase)
    else
      local aN = 1 - mix
      local aS = mix
      neonCoreNormal:SetAlpha(aN * coreBase);   neonCoreSmall:SetAlpha(aS * coreBase)
      neonInnerNormal:SetAlpha(aN * innerBase); neonInnerSmall:SetAlpha(aS * innerBase)
      neonEdgeNormal:SetAlpha((1 - mix) * edgeBase)
      neonEdgeSmall:SetAlpha(mix * edgeBase)
    end
  else
    -- ensure overlays are invisible if neon is off
    neonCoreNormal:SetAlpha(0); neonCoreSmall:SetAlpha(0)
    neonInnerNormal:SetAlpha(0); neonInnerSmall:SetAlpha(0)
    neonEdgeNormal:SetAlpha(0); neonEdgeSmall:SetAlpha(0)
  end
end

WantsSmallRing = function()
  -- While the colour picker is active, always use the default (large)
  -- ring size and ignore the mouselook-based small ring.
  if forceShowWhilePickingColour then
    return false
  end

  if not IsMouselookShrinkEnabled() then return false end
  return IsIntentionalMouselookActive()
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

  local mouselooking = IsMouselookActive()

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
      rmbIsDown = true
      rmbDownAt = GetTime()
      CaptureCursorNow()
    end
  end)

  WorldFrame:HookScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      rmbIsDown = false
      rmbDownAt = 0
    end
  end)
end

-- ---------------------------------------------------------------------
-- Visual refresh helpers
-- ---------------------------------------------------------------------

local function RefreshSize()
  local size = GetNormalizedSize()
  HelloCursorDB.size = size

  ringFrame:SetSize(HC.TUNE.RING_CANVAS_SIZE, HC.TUNE.RING_CANVAS_SIZE)

  local key = HC.Util.NearestKey(HC.TEX.RING, size) or 96

  -- Always keep spinner swipe textures correct (depends on current style)
  do
    local swipeNormal = HC.TEX.RING[key]
    local swipeSmall  = HC.TEX.RING_SMALL[key] or HC.TEX.RING[key]

    if gcdSpinnerNormal and gcdSpinnerNormal.SetSwipeTexture then
      gcdSpinnerNormal:SetSwipeTexture(swipeNormal)
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetSwipeTexture then
      gcdSpinnerSmall:SetSwipeTexture(swipeSmall)
    end
  end

  -- Always update BOTH styles so toggling neon on/off keeps the same size

  -- Flat ring
  HC.Util.SafeSetTexture(ringTexNormal, HC.TEX.RING[key], HC.TEX.RING[96])
  HC.Util.SafeSetTexture(ringTexSmall,  HC.TEX.RING_SMALL[key], HC.TEX.RING_SMALL[96] or HC.TEX.RING[96])

  -- Neon
  HC.Util.SafeSetTexture(neonCoreNormal,  HC.TEX.NEON_CORE[key],       HC.TEX.NEON_CORE[96])
  HC.Util.SafeSetTexture(neonCoreSmall,   HC.TEX.NEON_CORE_SMALL[key], HC.TEX.NEON_CORE_SMALL[96] or HC.TEX.NEON_CORE[96])

  HC.Util.SafeSetTexture(neonInnerNormal, HC.TEX.NEON_INNER[key],      HC.TEX.NEON_INNER[96])
  HC.Util.SafeSetTexture(neonInnerSmall,  HC.TEX.NEON_INNER_SMALL[key], HC.TEX.NEON_INNER_SMALL[96] or HC.TEX.NEON_INNER[96])

  HC.Util.SafeSetTexture(neonEdgeNormal, HC.TEX.NEON_EDGE[key], HC.TEX.NEON_EDGE[96])
  HC.Util.SafeSetTexture(neonEdgeSmall,  HC.TEX.NEON_EDGE_SMALL[key], HC.TEX.NEON_EDGE_SMALL[96] or HC.TEX.NEON_EDGE[96])

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

    -- If we're about to SHOW the ring (especially from hidden state),
    -- snap the cursor position + anchor BEFORE the first visible frame.
    if not wasShown then
      CaptureCursorNow()
      if UpdateRingPosition then UpdateRingPosition() end

      -- If the ring is appearing due to "show while mouselooking",
      -- force it to start at the LARGE ring on the first frame.
      if IsMouselookShowEnabled()
        and IsMouselookShrinkEnabled()
        and IsIntentionalMouselookActive()
      then
        -- hard reset the mix so it *starts* big then the OnUpdate tween shrinks it
        StopTween()
        currentMix = 0
        SetMix(0)
        -- optional: keep this consistent with your OnUpdate target tracking
        -- lastTargetMix = 0
      else
        -- normal behaviour
        SnapToTargetMix()
      end

      if HelloCursorDB.showGCDSpinner then
        gcdCheckAccum = 0
        CheckGCDPop()
      end
    end

    ringFrame:Show()

  else
    ringFrame:Hide()

    -- Optional but recommended: clear cached cursor so next show always
    -- re-captures and never uses a stale anchor.
    lastCursorX, lastCursorY = nil, nil
    wasMouselooking = false
  end
end

-- Always-on driver (lightweight) to react to menu open/close without relying on events.
-- Optimised: only does work when the addon is enabled AND when menu state actually changes.
local visibilityDriver = CreateFrame("Frame")
local visElapsed = 0
local lastMenuOpen = nil
local lastShouldShow = nil
local lastMouselookActive = nil

local function ForceVisibilityRecompute()
  lastMenuOpen = nil
  lastShouldShow = nil
  lastMouselookActive = nil
  UpdateVisibility()
end

visibilityDriver:SetScript("OnUpdate", function(_, elapsed)
  -- If the addon is off, do nothing.
  if not IsAddonEnabled() then
    if lastShouldShow ~= false then
      lastShouldShow = false
      if ringFrame:IsShown() then ringFrame:Hide() end
    end
    return
  end

  visElapsed = visElapsed + (elapsed or 0)
  if visElapsed < 0.10 then return end -- 10Hz is plenty for these checks
  visElapsed = 0

  local menuOpen = HelloCursorDB.hideInMenus and IsAnyMenuOpen() or false
  local mouselookActive = IsIntentionalMouselookActive()

  -- Only recompute visibility if menu state flipped (open/close),
  -- mouselook state changed (for the override), or if we don't have a baseline yet.
  if lastMenuOpen == nil
    or menuOpen ~= lastMenuOpen
    or (IsMouselookShowEnabled() and mouselookActive ~= lastMouselookActive)
  then
    lastMenuOpen = menuOpen
    lastMouselookActive = mouselookActive
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

  -- While the colour picker is active, completely lock the ring to
  -- the default (large) size and skip all reactive mouselook tweening.
  if forceShowWhilePickingColour then
    lastTargetMix = 0

    -- hard stop any tweening / mix changes
    if tweenActive then StopTween() end
    SetMix(0)

    -- absolutely no GCD logic while picker is open
    gcdCheckAccum = 0
    lastGCDBusy = false
    lastGCDRemaining = 0
    gcdVisualActive = false
    suppressFlatRing = false
    neonPulseStrength = 0

    HideGCDSpinners()
    if gcdPopAnim and gcdPopAnim:IsPlaying() then gcdPopAnim:Stop() end

    if UpdateRingPosition then UpdateRingPosition() end
    return
  end

  local targetMix = WantsSmallRing() and 1 or 0
  if targetMix ~= lastTargetMix then
    lastTargetMix = targetMix
    if HelloCursorDB.showGCDSpinner then
      CheckGCDPop() -- sync flags immediately on RMB toggle
    end
  end

  gcdCheckAccum = gcdCheckAccum + (elapsed or 0)
  if gcdCheckAccum >= HC.TUNE.GCD_POP_CHECK_INTERVAL then
    gcdCheckAccum = 0
    CheckGCDPop()
  end

  if tweenActive then
    local t = (GetTime() - tweenStart) / HC.TUNE.TWEEN_DURATION
    if t >= 1 then
      StopTween()
      SetMix(tweenTo)
    else
      SetMix(HC.Util.Lerp(tweenFrom, tweenTo, HC.Util.EaseInOut(t)))
    end
  else
    if math_abs(currentMix - targetMix) > 0.001 then
      StartTween(currentMix, targetMix)
    end
  end

  if IsNeonStyle() and neonPulseStrength > 0 then
    SetMix(currentMix)
  end

  if UpdateRingPosition then UpdateRingPosition() end
end)

-- ---------------------------------------------------------------------
-- Ring style change helper (classic vs neon)
-- ---------------------------------------------------------------------

local function ApplyRingStyleChange()
  SyncRingStyleFlags()

  if not IsNeonStyle() then
    neonPulseStrength = 0
  end

  RefreshSize()
  ApplyTintIfNeeded(true)
  StopTween()
  SnapToTargetMix()
end

HC.DEFAULTS = DEFAULTS
HC.CopyDefaults = HC.Util and HC.Util.CopyDefaults or nil
HC.NormalizeHex = HC.Util and HC.Util.NormalizeHex or nil
HC.Clamp = HC.Util and HC.Util.Clamp or nil
HC.NearestKey = HC.Util and HC.Util.NearestKey or nil

HC.HexToRGBA = HC.Util and HC.Util.HexToRGBA or nil
HC.RGBAtoHex = HC.Util and HC.Util.RGBAtoHex or nil

HC.RefreshSize = RefreshSize
HC.UpdateRingPosition = UpdateRingPosition
HC.StopTween = StopTween
HC.SetMix = SetMix
HC.SnapToTargetMix = SnapToTargetMix

HC.ForceVisibilityRecompute = ForceVisibilityRecompute
HC.SetForceShowWhilePickingColour = SetForceShowWhilePickingColour
HC.StartPickerCursorDriver = StartPickerCursorDriver
HC.StopPickerCursorDriver = StopPickerCursorDriver
HC.ResyncGCDVisualsAfterPicker = ResyncGCDVisualsAfterPicker

HC.HideGCDSpinners = HideGCDSpinners
HC.ApplyRingStyleChange = ApplyRingStyleChange

HC.CaptureCursorNow = CaptureCursorNow
HC.RefreshVisualsImmediate = RefreshVisualsImmediate
HC.UpdateVisibility = UpdateVisibility
HC.ApplyTintIfNeeded = ApplyTintIfNeeded
HC.IsAddonEnabled = IsAddonEnabled
HC.SyncRingStyleFlags = SyncRingStyleFlags
