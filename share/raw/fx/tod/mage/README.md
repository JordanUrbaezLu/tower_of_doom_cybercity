# Healing Aura player effect

`fx_healing_aura_player.efx` reuses the Mod Tools stock
`share/raw/fx/zombie/fx_bgb_near_death_3p.efx` (Near Death Experience).
The original blue color graph is tinted green for Healing Aura; each key keeps
its largest RGB channel as brightness, with RGB ratios 0.15 : 1 : 0.30.
All motion, sizes, lifetimes, the revive-symbol material, and near-camera fade
are unchanged. The original stock asset is not modified.

One effect host follows each healed player's upper torso. Repeated pulses and
overlapping auras refresh the existing host; leaving protection, downing, death,
or disconnect removes it. The existing green health bar is the first-person
indicator; this stock third-person effect fades near the camera.

# Ice shot comfort

The shared `fx_staff_ice_trail_clean.efx` omits the two large phosphor flash
sprites (oneshot3/4) and brief dynamic light (oneshot12). The three missiles
spawn near the camera, so these layers could overlap over the player view.
The ten other trail emitters remain byte-identical to the previous clean
effect. The earlier removal of lingering icicle models remains.

Both `../fx_tod_ice_muzzle_1p.efx` and `../fx_tod_ice_muzzle_3p.efx` remove
brief flash lights; the 1p effect also removes its lens flare. The large
glow is quarter-size with 20% alpha and a blue opening color. The largest
haze is one-fifth size and alpha, with a 220 ms lifetime. Small ice
particles and the existing projectile impact retain their definitions.
No weapon fields or gameplay numbers change. Native appearance must be
checked with repeated shots, close targets, and a nearby teammate.
