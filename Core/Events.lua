-- Hello Cursor Core Events Handler

local HC = HelloCursor
if not HC then return end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("UNIT_TARGET")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == HC.ADDON_NAME then
    -- Ensure SavedVariables table exists
    HelloCursorDB = HelloCursorDB or {}

    -- Migrate legacy visibility flags before seeding defaults.
    if HC.SyncVisibilityFlagsFromLegacy then
      HC.SyncVisibilityFlagsFromLegacy()
    end

    -- Now layer defaults on top for any keys that are still nil.
    HelloCursorDB = HC.CopyDefaults(HelloCursorDB, HC.DEFAULTS)
    if HC.GetNormalizedColorHex then
      HelloCursorDB.colorHex = HC.GetNormalizedColorHex()
    else
      HelloCursorDB.colorHex = (HC.NormalizeHex and HC.NormalizeHex(HelloCursorDB.colorHex))
        or (HC.DEFAULTS and HC.DEFAULTS.colorHex)
    end

    -- One-time migration for sizes
    if not HelloCursorDB._sizeMigration_2026_01 then
      local s = HelloCursorDB.size
      if type(s) == "string" then
        local key = s:lower()
        if key == "compact" then
          HelloCursorDB.size = "standard"
        elseif key == "standard" then
          HelloCursorDB.size = "medium"
        elseif key == "medium" then
          HelloCursorDB.size = "large"
        elseif key == "large" then
          HelloCursorDB.size = "large"
        end
      end

      HelloCursorDB._sizeMigration_2026_01 = true
    end

    -- Normalize legacy size values into the new named-size format.
    if HC.NormalizeSizeSetting then
      HelloCursorDB.size = HC.NormalizeSizeSetting(HelloCursorDB.size)
    else
      local size = tonumber(HelloCursorDB.size)
      if size == 192 then
        HelloCursorDB.size = 96
      end
    end

    if HC.SyncRingStyleFlags then
      HC.SyncRingStyleFlags()
    end

    -- Run color mode migration now that SavedVariables are loaded,
    -- so legacy useClassColor is correctly reflected in colorMode.
    if HC.SyncColorModeFromLegacy then
      HC.SyncColorModeFromLegacy()
    end

    -- After all migrations have run, clean up any legacy-only
    -- SavedVariables that are no longer used.
    if HC.CleanupLegacySavedVariables then
      HC.CleanupLegacySavedVariables()
    end

    HC.CaptureCursorNow()

    HC.RefreshVisualsImmediate()
    HC.UpdateVisibility()

    if not HC.settingsCategory then
      HC.settingsCategory = HC.CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. HC.VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")
    return
  end

  -- For target changes we generally only need to refresh the tint, so
  -- avoid kicking the full visibility pipeline unless necessary.
  if event == "PLAYER_TARGET_CHANGED" then
    if HelloCursorDB and (
      HelloCursorDB.colorMode == "target" or
      HelloCursorDB.aggroMode == "hostile" or
      HelloCursorDB.aggroMode == "threat"
    ) then
      HC.ApplyTintIfNeeded(false)
    end
    return
  end

  -- When using hostile or threat aggro display, threat changes can
  -- affect whether the ring should be red even if the target stays
  -- the same.
  if event == "UNIT_THREAT_SITUATION_UPDATE" then
    if HelloCursorDB
      and (HelloCursorDB.aggroMode == "hostile" or HelloCursorDB.aggroMode == "threat")
      and arg1 == "player" then
      HC.ApplyTintIfNeeded(false)
    end
    return
  end

  -- Some boss mechanics directly change who your target is attacking
  -- (fixates, target swaps) without generating a distinct threat
  -- event for the player. When "Threat" or "Hostile" aggro display
  -- is enabled, react to target-of-target changes so the ring tint
  -- can be updated based on the current target's target.
  if event == "UNIT_TARGET" then
    if HelloCursorDB
      and (HelloCursorDB.aggroMode == "hostile" or HelloCursorDB.aggroMode == "threat")
      and arg1 == "target" then
      HC.ApplyTintIfNeeded(false)
    end
    return
  end

  HC.ApplyTintIfNeeded(false)
  HC.UpdateVisibility()
end)

SLASH_HELLOCURSOR1 = "/hc"
SLASH_HELLOCURSOR2 = "/hellocursor"

SlashCmdList.HELLOCURSOR = function(msg)
  if msg == "toggle" then
    local current = HC.IsAddonEnabled()
    local newValue = not current
    HelloCursorDB.enabled = newValue
    HC.UpdateVisibility()
    print(("HelloCursor: %s"):format(HelloCursorDB.enabled and "enabled" or "disabled"))
    return
  end

  if HC.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(HC.settingsCategory:GetID())
  end
end
