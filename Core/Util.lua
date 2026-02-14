-- HelloCursor shared utility helpers

HelloCursor = HelloCursor or {}
local HC = HelloCursor

HC.Util = HC.Util or {}
local U = HC.Util

local math_abs          = math.abs

local DEFAULT_COLOR_HEX = "FF4FD8" -- fallback if HC.DEFAULTS is not yet populated

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

local function Lerp(a, b, t)
  return a + (b - a) * t
end

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
  local defaults = HC.DEFAULTS
  local defaultHex = (defaults and defaults.colorHex) or DEFAULT_COLOR_HEX

  hex = NormalizeHex(hex) or defaultHex

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

local function GetNormalizedColorHex()
  local defaults = HC.DEFAULTS
  local defaultHex = (defaults and defaults.colorHex) or DEFAULT_COLOR_HEX

  local currentHex = HelloCursorDB and HelloCursorDB.colorHex
  local norm = NormalizeHex and NormalizeHex(currentHex) or nil

  return norm or defaultHex
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

local function SafeSetTexture(tex, path, fallback)
  local ok = tex:SetTexture(path)
  if not ok and fallback then
    tex:SetTexture(fallback)
  end
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

-- Attach to HC.Util
U.CopyDefaults          = CopyDefaults
U.Clamp                 = Clamp
U.Lerp                  = Lerp
U.EaseInOut             = EaseInOut
U.NormalizeHex          = NormalizeHex
U.HexToRGBA             = HexToRGBA
U.RGBAtoHex             = RGBAtoHex
U.GetNormalizedColorHex = GetNormalizedColorHex
U.NearestKey            = NearestKey
U.SafeSetTexture        = SafeSetTexture
U.GetSpellCooldownCompat = GetSpellCooldownCompat
