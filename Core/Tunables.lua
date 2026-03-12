-- Hello Cursor tunable constants

HelloCursor = HelloCursor or {}
local HC = HelloCursor

HC.TUNE = {
  -- Tweening and GCD polling
  TWEEN_DURATION         = 0.08,
  GCD_SPELL_ID           = 61304,
  GCD_POP_CHECK_INTERVAL = 0.02,

  -- GCD pop animation
  GCD_POP_ENABLED   = true,
  GCD_POP_SCALE     = 1.28,
  GCD_POP_SCALE_X   = 1.30,
  GCD_POP_SCALE_Y   = 1.16,
  GCD_POP_UP_TIME   = 0.04,
  GCD_POP_DOWN_TIME = 0.10,

  -- RMB mouselook squash when the small ring first appears
  RMB_SQUASH_ENABLED   = true,
  RMB_SQUASH_SCALE_X   = 1.04,
  RMB_SQUASH_SCALE_Y   = 0.90,
  RMB_SQUASH_UP_TIME   = 0.04,
  RMB_SQUASH_DOWN_TIME = 0.10,

  -- Fixed canvas
  RING_CANVAS_SIZE = 192,

  -- Neon overlay alphas
  NEON_ALPHA_BASE  = 1.00,
  NEON_ALPHA_CORE  = 0.48,
  NEON_ALPHA_EDGE  = 0.38,

  -- Neon GCD pulsing behaviour
  NEON_GCD_PULSE_ENABLED = true,
  NEON_GCD_PULSE_SPEED   = 3.2,

  -- Pulse alpha ranges
  NEON_PULSE_CORE_MIN    = 0.18,
  NEON_PULSE_CORE_MAX    = 0.72,
  NEON_PULSE_EDGE_MIN    = 0.16,
  NEON_PULSE_EDGE_MAX    = 0.54,

  NEON_PULSE_USE_GCD_PROGRESS = false,
}
