-- HelloCursor tunable constants

HelloCursor = HelloCursor or {}
local HC = HelloCursor

HC.TUNE = {
  -- Tweening and GCD polling
  TWEEN_DURATION         = 0.08,
  GCD_SPELL_ID           = 61304, -- "Global Cooldown"
  GCD_POP_CHECK_INTERVAL = 0.02,  -- interval for polling GCD state

  -- GCD pop animation
  GCD_POP_ENABLED   = true,
  GCD_POP_SCALE     = 1.16,
  GCD_POP_UP_TIME   = 0.045,
  GCD_POP_DOWN_TIME = 0.075,

  -- Fixed canvas so ring thickness never scales (textures are authored for this)
  RING_CANVAS_SIZE = 128,

  -- Neon overlay alphas
  NEON_ALPHA_BASE  = 0.95,
  NEON_ALPHA_CORE  = 0.80,
  NEON_ALPHA_INNER = 0.85,

  -- Neon GCD pulsing behaviour
  NEON_GCD_PULSE_ENABLED = true,   -- master switch for neon GCD pulsing
  NEON_GCD_PULSE_SPEED   = 2.4,    -- oscillations per second

  -- Pulse alpha ranges
  NEON_PULSE_CORE_MIN  = 0.25,
  NEON_PULSE_CORE_MAX  = 1.00,
  NEON_PULSE_INNER_MIN = 0.20,
  NEON_PULSE_INNER_MAX = 1.00,

  -- Optional: if you still want intensity to ramp with GCD progress
  NEON_PULSE_USE_GCD_PROGRESS = false,  -- set true if you want ramp-up
}
