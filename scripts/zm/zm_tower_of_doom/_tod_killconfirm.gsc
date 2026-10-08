// Elite kill confirmation: immediate red marker, larger for a Panzer.
// User 2026-09-22 removed the Apex ding from headshot/elite luck events.
// Luck audio now belongs to the traveling soul and its actual arrival.
// The stock damage-feedback element, visual timing and reset remain unchanged.
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace tod_killconfirm;

// Marker sizes: stock's Panzer marker is 24x48 at (-12,-12) — the sprite's
// visible X lives in the top square of that tall quad, which is why the
// y-offset is half the WIDTH. Keep that rule and scale it.
#define TOD_KC_ELITE_W      28
#define TOD_KC_ELITE_HOLD   0.55
#define TOD_KC_BOSS_W       40
#define TOD_KC_BOSS_HOLD    0.95
#define TOD_KC_STOCK_W      24     // put back for the Panzer's own per-hit marker

function init()
{
	level.tod_killconfirm_on = true;
	dev_log( "init" );
}

// PUBLIC — an elite died to `player`. kind = "panzer" | "protector" | "reaver"
// | "hellhound" | "sprinter" (tod_luck::boss_kill's vocabulary).
function elite_kill( player, kind )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	big = ( isdefined( kind ) && kind == "panzer" );
	player show_marker( big );
	dev_log( "elite_kill kind=" + ( ( isdefined( kind ) ) ? kind : "?" ) + " big=" + big + " player=" + player GetEntityNumber() );
}

// self = player. The red snap. A newer marker takes over an older one's fade
// (sequence stamp), and the reset only runs for the newest.
function show_marker( big )
{
	e = self.hud_damagefeedback;
	if ( !isdefined( e ) )
		return;
	w = TOD_KC_ELITE_W;
	hold = TOD_KC_ELITE_HOLD;
	if ( IS_TRUE( big ) )
	{
		w = TOD_KC_BOSS_W;
		hold = TOD_KC_BOSS_HOLD;
	}
	if ( !isdefined( self.tod_kc_seq ) )
		self.tod_kc_seq = 0;
	self.tod_kc_seq++;
	seq = self.tod_kc_seq;

	e SetShader( "damage_feedback", w, w * 2 );
	e.x = -( w / 2 );
	e.y = -( w / 2 );
	e.color = ( 1, 0.18, 0.18 );
	e.alpha = 1;
	e FadeOverTime( hold );
	e.alpha = 0;
	self thread marker_reset( seq, hold );
}

// self = player. After the fade, hand the element back in stock's shape.
function marker_reset( seq, hold )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	wait hold + 0.05;
	if ( !isdefined( self ) || !isdefined( self.tod_kc_seq ) || self.tod_kc_seq != seq )
		return;   // a newer marker owns the element
	e = self.hud_damagefeedback;
	if ( !isdefined( e ) )
		return;
	e.alpha = 0;
	e.color = ( 1, 1, 1 );
	e SetShader( "damage_feedback", TOD_KC_STOCK_W, TOD_KC_STOCK_W * 2 );
	e.x = -( TOD_KC_STOCK_W / 2 );
	e.y = -( TOD_KC_STOCK_W / 2 );
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_KILLCONFIRM] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
