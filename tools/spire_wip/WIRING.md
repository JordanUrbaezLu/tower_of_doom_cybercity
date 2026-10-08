# spire_wip/WIRING.md — phase-2 checklist (apply ONLY after UPLOAD CONFIRMED)

`_tod_spire.gsc` is ALREADY WRITTEN into scripts/ (inert — no zone line). This
file is the exact remaining wiring. Order matters; build once at the end.

## 1. tools/ port
- Apply `gen_tower_map.SPIRE.js` over `tools/gen_tower_map.js` (flag stays
  false), regen, PROVE byte-identical .map, then flip `SPIRE_ENABLED = true`.
- Replace `lint_tod_geometry.js` + `lint_tod_geometry_selftest.js` with the
  .SPIRE versions; run the selftest (expect 10/10).

## 2. _tod_finale.gsc — the choice replaces auto-depart
a) In `finale_run`, replace the final `level thread depart();` with:
```
	if ( IS_TRUE( level.tod_spire_ready ) )
		level thread choice_phase();
	else
		level thread depart();
```
b) Add (near depart()):
```
// THE CHOICE (docs/44): the win holds; two stations glow. EXTRACT = the pad,
// ASCEND = the dais teleporter (_tod_spire owns that half via notifies).
function choice_phase()
{
	level endon( "end_game" );
	level endon( "tod_ascend" );

	level.tod_finale_state = "choice";
	level.tod_choice_pending = true;   // spawn starve (_tod_endless_rounds)
	wipe_the_map();
	tod_atmosphere::channel_stop();    // the song is over; the choice is quiet
	level thread choice_banners();
	level notify( "tod_choice_begin" );
	level thread extract_use_loop();

	level waittill( "tod_extract" );
	level.tod_choice_pending = undefined;
	level thread depart();
}

function extract_use_loop()
{
	level endon( "end_game" );
	level endon( "tod_ascend" );
	t = level.tod_finale_pad_trig;
	if ( !isdefined( t ) )
		return;
	t SetHintString( "Hold ^3[{+activate}]^7 ^2EXTRACT^7 - leave the tower" );
	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		level notify( "tod_extract" );
		return;
	}
}

function choice_banners()
{
	level endon( "end_game" );
	elems = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		e = NewClientHudElem( p );
		if ( !isdefined( e ) )
			continue;
		e.alignX = "center"; e.alignY = "middle";
		e.horzAlign = "center"; e.vertAlign = "middle";
		e.y -= 170; e.foreground = true; e.color = ( 1, 1, 1 );
		e.hidewheninmenu = true; e.alpha = 0;
		e SetShader( "tod_choice_banner", 720, 180 );
		e FadeOverTime( 1 ); e.alpha = 1;
		elems[ elems.size ] = e;
	}
	util::waittill_any( "tod_extract", "tod_ascend" );
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
			elems[ i ] Destroy();
	}
}
```
   (util::waittill_any — self=level: call as `level util::waittill_any(...)`.
   Verify its exact name in util_shared at apply time; else two tiny waiter
   threads + one notify.)
c) `exfil_hint_loop` switch: add `case "choice":` ABOVE "ready" — the extract
   loop stamps its own hint; the case just prevents the default. Add
   `#precache( "material", "tod_choice_banner" );` with the other precaches.
d) `uplink_hint_loop`: "choice" falls to default ("") — no edit needed.

## 3. _tod_bosses.gsc — one line
In `finale_pressure_loop()`, under `level endon( "end_game" );` add:
```
	level endon( "tod_ascend" );   // the spire retires the finale's pressure
```

## 4. _tod_endless_rounds.gsc
a) `#using scripts\zm\zm_tower_of_doom\_tod_spire_data;` (leaf module, no cycle)
b) Top of `tod_spawn_delay` (before the stock resolve):
```
	// THE CHOICE holds its breath; THE SPIRE runs hot (docs/44 §6a).
	if ( IS_TRUE( level.tod_choice_pending ) )
		return 999;
	if ( IS_TRUE( level.tod_spire_active ) )
		return 0.18;
```
   (0.18 = TOD_SPIRE_SPAWN_FLOOR — keep in lockstep with _tod_spire.gsc.)
c) In `finale_spawn_selection`, after the crown-sealed filter block:
```
	// THE SPIRE (docs/44): once ascended, only spire risers at or below the
	// highest bought door are eligible — a riser above it is the stranded-
	// actor trap the gate filter exists to prevent, one flight up.
	if ( IS_TRUE( level.tod_spire_active ) )
	{
		ok = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			if ( !( tod_spire_data::in_spire( sp.origin ) ) )
				continue;
			if ( sp.origin[ 2 ] > level.tod_spire_door_max_z )
				continue;
			ok[ ok.size ] = sp;
		}
		if ( ok.size > 0 )
			spots = ok;
	}
```

## 5. zm_tower_of_doom.gsc (entry)
a) `#using scripts\zm\zm_tower_of_doom\_tod_spire;` (with the tod modules)
b) In main(), after the teleport init: `level thread tod_spire::init();`
c) `level.perk_purchase_limit = 9;` -> `10` + comment: the roster has been 10
   since PhD joined the scatter (9 machines + Mule Kick) — 9 was a stale count,
   and the spire grant hands out all 10.
d) In `usermap_test_zone_init()` append:
```
	// THE ENDLESS SPIRE (docs/44): base <- the ascension itself; then one
	// chunk per 5 floors, chained on each chunk's FIRST door; summit rides
	// the last door's flag.
	zm_zonemgr::add_adjacent_zone( "roof_zone", "spire_base_zone", "tod_ascension" );
	zm_zonemgr::add_adjacent_zone( "spire_base_zone", "spire_c1_zone", "enter_spire1" );
	for ( i = 1; i < 20; i++ )
		zm_zonemgr::add_adjacent_zone( "spire_c" + i + "_zone", "spire_c" + ( i + 1 ) + "_zone", "enter_spire" + ( i * 5 + 1 ) );
	zm_zonemgr::add_adjacent_zone( "spire_c20_zone", "spire_summit_zone", "enter_spire100" );
```

## 6. zone_source/zm_tower_of_doom.zone
- `scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_spire.gsc`
- `scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_spire_data.gsc`
- Clone the win-banner asset pattern (lines ~298-300) for the five arts:
  `image,i_tod_choice_banner` … `material,tod_choice_banner` … (×5)

## 7. Art install (a .gdt change = FULL build)
- 5 PNGs from `spire_wip/art/` -> `source_data/tod_ui_images/_images/`
- `source_data/tod_ui_images.gdt`: clone i_tod_win_banner's image.gdf block +
  tod_win_banner's 2d_blend material block per asset (emblem clones the
  win_emblem pair). KEEP names exactly: i_tod_choice_banner,
  i_tod_spire_banner, i_tod_spire_over_banner, i_tod_spire_win_banner,
  i_tod_spire_emblem (+ materials minus the i_ prefix).

## 8. Music
- `spire_wip/tod_music_spire.wav` -> `sound_assets/tod/music/`
- `sound/aliases/tod_ui.csv`: clone the tod_ambient_music row; Name
  tod_music_spire, FileSpec tod\music\tod_music_spire.wav.
- CREDITS.md: "Neon Static" — generated with Suno v5.5 for this map.

## 9. Build + gates
FULL build (announce BUILD START/FINISHED to sessions; one builder; quiet on
game-up). Then: lint (expect the spire lines green), `_bake_test`
(BAKED/CRASHED only — if CRASHED: spire PARA_EVERY 2->4 first),
`measure_lit_area` A/B, arity lint, freshness diffs, banks byte-check
(the wav ADDS to .sabs — byte-equal is NOT expected on this build; verify by
filename-grep instead). CHANGELOG entry. Baseline: the lint's spire fields
appear — re-run `--update` ONLY if the numbers are understood (expect
spireDetached 0).

## 10. Live-verify ladder (the user's run)
choice both ways -> grant audit (v16.36: perk slots + perks land, build otherwise untouched; a down + revive keeps the perks; a trial win deals cards) -> climb
window churn (doors sequential, crates materialize) -> hub vendors (PaP + 2
perks + crate) -> a down/respawn on the spire -> wipe screen -> summit
extraction screen. Boss cadence + Panzer music override on the spire.
