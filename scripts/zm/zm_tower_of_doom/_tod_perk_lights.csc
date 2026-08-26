// =============================================================================
// _tod_perk_lights.csc — perk machine + Pack-a-Punch GLOW (client half).
// DIRECT PORT of map 1's _acc_perk_lights.csc (the render half — stock
// power-up glow is client-side clientfield + PlayFXOnTag and DOES render).
//
// The fx assets are map 1's self-authored recoloured clones of the stock green
// power-up aura (installed at <tools>\share\raw\fx\acc\light\, sources carried
// in this repo under share\raw\fx\acc\light\, packed via the `fx,acc/light/*`
// lines in zone_source).
//
// LOCKSTEP: scope/name/version/bits/type here MUST equal _tod_perk_lights.gsc.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// Client-side precache of every glow FX (the half map 1's first attempt missed
// — server #precache("fx") alone leaves clients with no asset to draw).
#precache( "client_fx", "acc/light/fx_perk_glow_red" );
#precache( "client_fx", "acc/light/fx_perk_glow_green" );
#precache( "client_fx", "acc/light/fx_perk_glow_yellow" );
#precache( "client_fx", "acc/light/fx_perk_glow_orange" );
#precache( "client_fx", "acc/light/fx_perk_glow_amber" );
#precache( "client_fx", "acc/light/fx_perk_glow_blue" );
#precache( "client_fx", "acc/light/fx_perk_glow_blacklight" );
#precache( "client_fx", "acc/light/fx_perk_glow_white" );
#precache( "client_fx", "acc/light/fx_perk_glow_purple" );
#precache( "client_fx", "acc/light/fx_perk_glow_teal" );

#namespace tod_perk_lights;

REGISTER_SYSTEM( "tod_perk_lights", &__init__, undefined )

function __init__()
{
	// index -> glow FX (matches tod_perk_lights::perk_color_index)
	level._effect[ "tod_glow_1" ]  = "acc/light/fx_perk_glow_red";        // Jugg
	level._effect[ "tod_glow_2" ]  = "acc/light/fx_perk_glow_green";      // Speed Cola
	level._effect[ "tod_glow_3" ]  = "acc/light/fx_perk_glow_yellow";     // Double Tap
	level._effect[ "tod_glow_4" ]  = "acc/light/fx_perk_glow_orange";     // Stamin-Up
	level._effect[ "tod_glow_5" ]  = "acc/light/fx_perk_glow_amber";      // Mule Kick
	level._effect[ "tod_glow_6" ]  = "acc/light/fx_perk_glow_blue";       // Quick Revive
	level._effect[ "tod_glow_7" ]  = "acc/light/fx_perk_glow_blacklight"; // Deadshot
	level._effect[ "tod_glow_8" ]  = "acc/light/fx_perk_glow_white";      // Widow's Wine
	level._effect[ "tod_glow_9" ]  = "acc/light/fx_perk_glow_purple";     // (spare)
	level._effect[ "tod_glow_10" ] = "acc/light/fx_perk_glow_teal";       // PaP / generic

	// MUST match _tod_perk_lights.gsc EXACTLY. !CF_CALLBACK_ZERO_ON_NEW_ENT so
	// the latched value replays for clients that join AFTER power-on.
	clientfield::register( "scriptmover", "todPerkGlow", VERSION_SHIP, 4, "int", &glow_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// self = the machine script_model (or the PaP host). newVal = colour index (0 = off).
function glow_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( !isdefined( newVal ) || newVal == 0 )
	{
		if ( isdefined( self.tod_glow_fx ) )
		{
			StopFX( localClientNum, self.tod_glow_fx );
			self.tod_glow_fx = undefined;
		}
		return;
	}

	fx = level._effect[ "tod_glow_" + newVal ];
	if ( !isdefined( fx ) )
		return;

	// The model dobj must exist before PlayFXOnTag can resolve "tag_origin".
	self util::waittill_dobj( localClientNum );
	if ( !isdefined( self ) )
		return;

	if ( isdefined( self.tod_glow_fx ) )
		StopFX( localClientNum, self.tod_glow_fx );

	self.tod_glow_fx = PlayFXOnTag( localClientNum, fx, self, "tag_origin" );
}
