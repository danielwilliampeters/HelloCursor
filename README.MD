# Hello Cursor

A World of Warcraft addon that adds a smooth, highly visible ring around your mouse cursor, making it much easier to track during combat, fast camera movement, and busy encounters.

Designed for Retail with performance, polish, and configurability in mind.

## Features

- **Highly visible cursor ring**: Adds a hollow ring around your cursor so it never gets lost in combat
- **Color modes**: Choose a fixed color, use your class color, or automatically match your current target's faction reaction
- **Reactive cursor mode**: Smoothly shrinks the ring while holding right mouse (mouselook), enabled by default (can be turned off)
- **Freeze on mouselook**: Ring stays at the last cursor position when camera movement begins
- **Zone-aware visibility**: Control visibility for the open world, player housing, and instanced content via a simple instances dropdown (None / PvE / PvP / All)
- **Show ring modes**: Choose between always showing the ring (respecting per-zone "Do Not Show" overrides) or only showing it while you are in combat
- **Global cooldown indicator**: Optional GCD visual on the cursor ring (enabled by default)
- **Classic vs neon style**: Choose between a flat classic ring or a neon-style ring with inner glow
- **Polished animation**: Subtle 0.08s size tween for smooth transitions
- **Defaults reset**: Restore all settings with a single click
- **Lightweight**: Extremely low performance impact (single frame, asset-based rendering)
- **Slash commands**: Quick access to settings via `/hc` or `/hellocursor`

## Configuration

- Open the settings panel via `/hc`, `/hellocursor`, or the Interface → Options → AddOns → Hello Cursor entry.
- Under **Show Ring**, choose:
  - **Always** – ring visibility is controlled by the per-zone **Do Not Show** options (open world, instances, housing)
  - **Combat Only** – the ring is hidden out of combat and shown whenever you are in combat, regardless of zone (still respects the addon enable/menus/mouselook rules)
- Adjust per-zone visibility using **Do Not Show in Open World**, **Do Not Show Inside Instances** (None / PvE / PvP / All), and **Do Not Show in Player Housing**.
- Toggle reactive cursor mode, the global cooldown animation, and whether the ring hides while game menus are open.
- Under **Ring Color**, choose between:
  - **Default** – your configured ring color (via color picker or hex)
  - **Class** – your class color
  - **Target** – use your current target's faction reaction color (hostile/neutral/friendly)
- Under **Aggro Display**, choose between:
  - **None** – no extra aggro-based highlighting
  - **Hostile** – red when your target is hostile or otherwise treated as hostile/engaged (attackable, alive, and either red reaction or has threat on you)
  - **Threat** – red whenever your current, attackable, live target has non-zero threat on you
- Select ring size, and switch between classic and neon ring styles.

## Installation

1. Download the addon
2. Extract the `HelloCursor` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart World of Warcraft or reload your UI with `/reload`
