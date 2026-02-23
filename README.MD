# Hello Cursor

A World of Warcraft addon that adds a smooth, highly visible ring around your mouse cursor, making it much easier to track during combat, fast camera movement, and busy encounters.

Designed for Retail with performance, polish, and configurability in mind.

## Features

- **Highly visible cursor ring**: Adds a hollow ring around your cursor so it never gets lost in combat
- **Color modes**: Choose a fixed color, use your class color, react to target type (friendly/neutral/hostile), highlight hostile/engaged targets, or light up purely on threat
- **Reactive cursor mode**: Smoothly shrinks the ring while holding right mouse (mouselook), enabled by default (can be turned off)
- **Freeze on mouselook**: Ring stays at the last cursor position when camera movement begins
- **Zone-aware visibility**: Control visibility for the open world, player housing, and instanced content via a simple instances dropdown (None / PvE / PvP / All)
- **Show in combat**: Display the ring whenever you are in combat (enabled by default)
- **Global cooldown indicator**: Optional GCD visual on the cursor ring (enabled by default)
- **Classic vs neon style**: Choose between a flat classic ring or a neon-style ring with inner glow
- **Polished animation**: Subtle 0.08s size tween for smooth transitions
- **Defaults reset**: Restore all settings with a single click
- **Lightweight**: Extremely low performance impact (single frame, asset-based rendering)
- **Slash commands**: Quick access to settings via `/hc` or `/hellocursor`

## Configuration

- Open the settings panel via `/hc`, `/hellocursor`, or the Interface → Options → AddOns → Hello Cursor entry.
- Adjust visibility per zone type: outside instances, player housing, and instanced content using the **Do Not Show in Instances** dropdown (None / PvE / PvP / All), and choose whether the ring always shows in combat.
- Toggle reactive cursor mode, the global cooldown animation, and whether the ring hides while game menus are open.
- Under **Ring Color**, choose between:
	- **Default** – your configured ring color (via color picker or hex)
	- **Class** – your class color
	- **Target Type** – color based on target reaction (friendly / neutral / hostile)
	- **Combat Highlight** – red when your target is hostile or engaged with you (has threat and is attackable/alive)
	- **Threat** – red whenever your current, attackable, live target has threat on you
- Select ring size, and switch between classic and neon ring styles.

## Installation

1. Download the addon
2. Extract the `HelloCursor` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart World of Warcraft or reload your UI with `/reload`
