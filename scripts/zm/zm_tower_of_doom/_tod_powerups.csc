// =============================================================================
// _tod_powerups.csc — client half of the map's custom powerup drops.
// Stock contract (_zm_powerup_free_perk.csc precedent): the csc must
// include_zombie_powerup ITSELF (only the server side auto-includes via
// register_powerup), then add_zombie_powerup — with the SAME clientfield
// name/version as the gsc for the timed admin gun, or the toplayer
// clientfield registration mismatches at load.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\filter_shared;          // v19.65: the Zombie Blood filter's material id
#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;   // v19.65: the Zombie Blood filter overlay

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_powerups;

#namespace tod_powerups;

// ZOMBIE BLOOD'S SCREEN FILTER (v19.65) - the client half. LOCKSTEP _tod_powerups.gsc:
// the overlay name, VERSION_SHIP and the lerp steps (both halves' register calls
// build the same visionset_mgr clientfields). The server owns WHEN (the window's
// countdown); this half owns WHAT: Treyarch's Zombie Blood filter, a RETAIL
// zm_common material every zombies map loads (no zone line, none possible).
// Filter 0 / pass 0: nothing else in this map drives a filter pass (the one other
// overlay the map ever had, the Panzer's burn, was removed).
//
// THE SHADER'S KNOBS, READ FROM THE SHADER ITSELF (v19.65b, 2026-09-30). The first
// build fed constant 0 only and the user saw "definitely a distortion but no tint".
// techset `zombie_blood` (share/raw/techsetdefs_stable/2d/zombie_blood.techsetdef)
// runs postfx/zombie_blood.hlsl; its compiled pixel shader (assetconvert/shaders/
// pc/v7, disassembled with d3dcompiler_47) reads ONLY scriptVector0, i.e. filter
// pass constants 0..3:
//   0 = .x  the WARP: min(|x|,1) x warpPixels x the reveal map (sign = direction)
//   1 = .y  the COLOUR LAYER (colorMap, zoom-animated) AND the BLOOD MOTES, saturated
//   2 = .z  the colour MASK reach: saturate( colorMask x z ) multiplies the colour
//   3 = .w  unused
// So the tint needs BOTH 1 and 2 (either at 0 hides it). Stock visionset_mgr's
// filter style writes one constant, so a custom enable (level.vsmgr_filter_custom_
// enable, the stock hook - no stock caller) writes all three, scaled by the fade.
#define TOD_BLOOD_VSMGR          "tod_zombie_blood"
#define TOD_BLOOD_VS_LERP        16
#define TOD_BLOOD_FILTER         "generic_filter_zombie_blood"
#define TOD_BLOOD_FILTER_INDEX   0
#define TOD_BLOOD_FILTER_PASS    0
#define TOD_BLOOD_FILTER_FADE    0      // the stock path's one constant (the warp); the custom enable supersedes it
#define TOD_BLOOD_WARP           1.0    // constant 0 at full fade (the distortion the first build showed)
#define TOD_BLOOD_TINT           1.0    // constant 1 at full fade: colour + blood motes (saturates at 1)
#define TOD_BLOOD_MASK           1.0    // constant 2: mask reach - raise above 1 to spread the colour inward

REGISTER_SYSTEM( "tod_powerups", &__init__, undefined )

function __init__()
{
	// First frame, like the server's register_info (both assert initialisation).
	visionset_mgr::register_overlay_info_style_filter( TOD_BLOOD_VSMGR, VERSION_SHIP, TOD_BLOOD_VS_LERP, TOD_BLOOD_FILTER_INDEX, TOD_BLOOD_FILTER_PASS, TOD_BLOOD_FILTER, TOD_BLOOD_FILTER_FADE );
	// The tint lives on constants 1 + 2 (header note): the stock hook, keyed by the
	// material name, replaces the one-constant enable. The disable stays stock (its
	// lookup keys on the CURRENT slot's material, so at switch-off it takes the
	// default branch - setfilterpassenabled false - which is exactly right).
	level.vsmgr_filter_custom_enable[ TOD_BLOOD_FILTER ] = &blood_filter_enable;
	// visionset_mgr draws a filter overlay through level.filter_matid[ material ],
	// which only filter::map_material_* fills: map it before any grab can arrive.
	callback::on_localclient_connect( &blood_filter_map );
	callback::on_localplayer_spawned( &blood_filter_map );

	// instant — no HUD timer field (admin gun removed on user order 2026-08-20)
	zm_powerups::include_zombie_powerup( "tod_free_pap" );
	zm_powerups::add_zombie_powerup( "tod_free_pap" );

	// [tod 2026-08-21] Free Pack-a-Punch (ZoekMeMaar model) + Zombie Blood
	// (NSZ model). Both instant/no-timer, so no clientfield to keep in
	// lockstep — but the csc MUST include+add each one itself or the client
	// never learns the powerup exists and the drop renders wrong.
	zm_powerups::include_zombie_powerup( "tod_pap" );
	zm_powerups::add_zombie_powerup( "tod_pap" );

	// ZOMBIE BLOOD — RE-ENABLED 2026-08-26, RESTORING THE LOCKSTEP THIS FILE'S
	// OWN HEADER DEMANDS. The drop was disabled on both halves on 2026-08-21;
	// when the user asked for it back on 2026-08-25 only the SERVER half was
	// switched on (register + add + the two setters in _tod_powerups.gsc), and
	// this half stayed commented out. Per the contract at the top of this
	// file, register_powerup auto-includes on the server ONLY — the csc must
	// include+add itself or the client never learns the powerup exists and the
	// drop renders wrong.
	// TIMED SINCE 2026-08-26 ("zombie blood doesn't show in the bar"): the
	// clientfield arg here MUST match the gsc add_zombie_powerup's
	// client_field_name (both "tod_zombie_blood", both VERSION_SHIP, both
	// 2-bit "toplayer") or the registration mismatches at load. This add also
	// enrolls the field in set_clientfield_code_callbacks' pass, which is what
	// lets the Aetherium tray row (AetheriumPowerupsContainer.lua) see it.
	zm_powerups::include_zombie_powerup( "tod_zombie_blood" );
	zm_powerups::add_zombie_powerup( "tod_zombie_blood", "tod_zombie_blood" );
}

// self = the local player (visionset_mgr calls `player [[ enable ]]( state,
// prev_info, curr_info )` on the slot change and on EVERY fade step). Writes the
// three constants the shader reads, all following the server's fade.
function blood_filter_enable( state, prev_info, curr_info )
{
	if ( state.prev_slot != state.curr_slot )
		blood_filter_guard_infos();   // before the switch-OFF can ever run (see below)
	lcn = self.localClientNum;
	filter::map_material_if_undefined( lcn, curr_info.material_name );
	f = state.curr_lerp;
	setfilterpassmaterial( lcn, curr_info.filter_index, curr_info.pass_index, filter::mapped_material_id( curr_info.material_name ) );
	setfilterpassenabled( lcn, curr_info.filter_index, curr_info.pass_index, true );
	setfilterpassconstant( lcn, curr_info.filter_index, curr_info.pass_index, 0, TOD_BLOOD_WARP * f );
	setfilterpassconstant( lcn, curr_info.filter_index, curr_info.pass_index, 1, TOD_BLOOD_TINT * f );
	setfilterpassconstant( lcn, curr_info.filter_index, curr_info.pass_index, 2, TOD_BLOOD_MASK );
	if ( state.prev_slot != state.curr_slot )
	{
		line = "[TOD_BLOOD_C] ON lcn=" + lcn + " warp=" + TOD_BLOOD_WARP + " tint=" + TOD_BLOOD_TINT + " mask=" + TOD_BLOOD_MASK + " fade=" + f;
		/#
		PrintLn( line );
		#/
	}
}

// Both callbacks pass the local client number. map_material_if_undefined is
// idempotent. The log line (devblock only, once per map) is the evidence that
// the retail material resolved: an id of -1 or undefined means it did not load
// and the filter cannot draw, whatever the server's [TOD_BLOOD] FX_ON says.
// THE STOCK SWITCH-OFF TRAP (v19.65b, caught in the user's first test log:
// "[SCRIPTERROR] undefined is not an array index" in visionset_mgr_shared.csc, the
// moment Zombie Blood ended). overlay_update_cb's FILTER disable branch looks up
// level.vsmgr_filter_custom_disable[ curr_info.material_name ] with the slot it is
// switching TO - at switch-off that is "__none", which has no material_name, so the
// index is undefined and it throws BEFORE setfilterpassenabled( false ): the filter
// stays on and that update dies. No stock script ever used a filter overlay, so
// stock never reached it. Patch the DATA, not stock: every overlay info without a
// material_name gets a placeholder that keys nothing, the lookup yields undefined,
// and the default disable runs. Idempotent; run once every registration exists
// (local-client connect) and again whenever the filter switches on.
function blood_filter_guard_infos()
{
	if ( !isdefined( level.vsmgr ) || !isdefined( level.vsmgr[ "overlay" ] ) || !isdefined( level.vsmgr[ "overlay" ].info ) )
		return;
	foreach ( name, info in level.vsmgr[ "overlay" ].info )
	{
		if ( isdefined( info ) && !isdefined( info.material_name ) )
			info.material_name = "tod_no_filter_" + name;
	}
}

function blood_filter_map( localClientNum )
{
	blood_filter_guard_infos();
	if ( isdefined( filter::mapped_material_id( TOD_BLOOD_FILTER ) ) )
		return;
	filter::map_material_if_undefined( localClientNum, TOD_BLOOD_FILTER );
	id = filter::mapped_material_id( TOD_BLOOD_FILTER );
	line = "[TOD_BLOOD_C] filter=" + TOD_BLOOD_FILTER + " lcn=" + localClientNum + " matid=" + ( ( isdefined( id ) ) ? id : "undefined" );
	/#
	PrintLn( line );
	#/
}
