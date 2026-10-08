// =============================================================================
// _tod_secret.gsc — THE TEDDY BEAR SONG HUNT (v18.96, 2026-09-13; user: "There
// will be teddybears at base, breather 1, and breather 2. If you shoot all 3
// you activate the song").
//
// THE MAP'S FIRST SECRET. Three teddy bears sit off the path. Since v19.64
// (2026-09-30, user: "update the teddy bear to the cyber teddy") they are a
// fan's CYBER TEDDY (`tod_cyber_teddy`, made with Meshy AI, converted by
// tools/cyber_teddy/build_cyber_teddy.py); v18.96..v19.63 used the stock
// mystery-box bear `p7_zm_teddybear`:
//
//   #0  THE BASE — on the power-hall floor beside the switch, the far corner.
//   #1  BREATHER 1 (floor 10) — on the lounge floor, back to the outer wall.
//   #2  BREATHER 2 (floor 20) — on top of the second gantry hoop over the
//       teleporter spur, 240 up, silhouetted against the city.
//
// SHOOT ONE: the bear laughs (the stock Samantha laugh alias, played in 3D at
// the bear so the whole party hears WHERE), a derez burst, and it is gone.
// SHOOT ALL THREE, any order: a sting for everyone and the song takes the
// music channel for its full length (_tod_atmosphere::ee_song_start —
// "Beauty of Annihilation"), then the band track resumes. Once per match.
//
// DETECTION IS SHOOTING — SetCanDamage + the engine's "damage" notify (stock
// _zm_blockers' glass-barricade lane) — so this spends NONE of the 250
// triggerstring slots, no clientfield bits, no registrations. No text on
// screen (the no-floaty-text rule): the laugh and the burst are the whole
// affordance, the song is the reward.
//
// Coordinates are the generator's own numbers (gen_tower_map.js: the lounge is
// authored in the odd frame and MIRRORED for the even laps 10/20 — x[-820,-256]
// y[-1012,-396] in world; the E-wall band x[-820,-800], mullion b at
// y[-814,-786], NB1 at y=-992; hoop 2 lintel x[-824,-584] y[-1232,-1212]
// z[mid+192, mid+240]; the power switch - since v19.69 the Grid Terminal panel
// (gen_tower_map.js POWER_TERM), y[-495,-433] on the end wall - in the hall
// y[-540,-420] ending at x=1640) and the lounge floor z from the GENERATED
// _tod_breather_data::breather_zs().
//
// Dev log tag: [TOD_SECRET] — placement, each find, the song, refusals.
// =============================================================================
#using scripts\shared\callbacks_shared;   // on_spawned — the per-player shot watcher (v18.96b)
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // GENERATED — breather_zs()
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;    // derez_burst / play_sound_at_origin (proven hosts)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;      // ee_song_start (the channel's one owner)

#insert scripts\shared\shared.gsh;

#precache( "model", "tod_cyber_teddy" );

#namespace tod_secret;

#define TOD_SECRET_MODEL        "tod_cyber_teddy"     // v19.64: the fan's Cyber Teddy (was the stock p7_zm_teddybear)
#define TOD_SECRET_REVISION     "cyber_teddy_1"       // = art/cyber_teddy/manifest.json "revision"; logged at INIT
#define TOD_SECRET_COUNT        3
#define TOD_SECRET_LAUGH        "tod_secret_laugh"    // v18.96b: OUR alias (tod_ui.csv, 3D, 6000u). zmb_laugh_child lives in a Kortifex CSV this map never loads — it was silent in the first test
#define TOD_SECRET_HIT          "tod_teleport_fire"   // v18.96b: the instant 3D "you hit it" zap under the laugh
#define TOD_SECRET_LAUGH_SECS   10                    // v18.96d: the Samantha laugh wav is 8.30 s (cut before its "bye bye"); the emitter outlives it
// v18.96c — THE RISE AND THE FLIGHT (user: "a long one so ... some raise and fly
// away animation for the teddy bear"). Paced to the laugh: RISE_SECS up and
// one slow turn, a HOVER (a gentle bob) while she laughs, then the burst and
// FLY_SECS straight up and outward from the tower — gone by the last giggle.
// Rise + fly = 8.1 s against the 8.3 s laugh (v18.96d, cut before the "bye bye"). Scripted movers
// (MoveZ / MoveTo / RotateYaw): the prop has no bones for the stock box-teddy
// xanim, and movers need no asset at all.
// v18.96e (user: "slowly spin and rise and it slowly spins faster and faster then
// flies out"): ONE RotateYaw over the whole exit with accel = its full time,
// so the spin rate ramps from zero to its peak at the launch (2160 deg over
// 8.1 s = six turns, ~1.5 turns/s at the end); a slow accelerating rise
// under it; then the launch, still spinning.
#define TOD_SECRET_RISE_Z       48
#define TOD_SECRET_RISE_SECS    6.5
#define TOD_SECRET_SPIN_DEG     4320   // v18.96g: 2x (user) — twelve turns, ~3 turns/s at the launch
#define TOD_SECRET_FLY_SECS     1.6
#define TOD_SECRET_FLY_Z        2400
#define TOD_SECRET_FLY_OUT      900                   // lateral drift away from the tower's core
#define TOD_SECRET_STING        "tod_ultimate_sting"  // 2D, everyone, on the third bear
#define TOD_SECRET_VANISH_SECS  0.35
#define TOD_SECRET_HOOP_TOP     240                   // hoop lintel top above the lounge floor
// v18.96b — THE PIVOT IS THE BEAR'S CENTRE, NOT ITS FEET. Decoded from the
// stock xmodel_bin (6,519 verts): x -9.1..9.2, y -6.0..6.0, z -14.2..13.9 —
// 18 x 12 x 28 units. The first test placed origins ON the surfaces and half
// of every bear sat inside them (user: "inside the floor and walls"). Every
// spot is a SURFACE height; the lift puts the feet one unit above it.
// v18.96f: PIXEL-PERFECT — the mesh's lowest vertex is z -14.2, so the pivot
// sits 14.2 above the floor and the feet touch it. The mesh is 18 wide (its
// local X) and 12 deep (local Y): the FRONT is local -Y (the vending-model
// convention this map's power switch is placed by), so "facing D" is the yaw
// that maps local -Y onto D (east 90, west 270, +Y 180), and "back to a
// wall" puts the pivot 6 off that wall's inner face.
// v19.64 — THE CYBER TEDDY KEEPS THE RULE WITH ITS OWN NUMBERS. The build tool
// pivots it at its bounding-box centre with the front on local -Y (so the three
// yaws below stand), 22.6 wide x 15.7 deep x 28 tall: LIFT = its -min z (14.0),
// HALF_DEPTH = its BACK extent, rounded up (7.85 -> 7.9). Both are written to
// art/cyber_teddy/manifest.json and test_v1896_secret_killconfirm_bottle.js
// fails if these drift from it. Keeping the stock 14.2 / 6 would have sunk the
// new bear 1.9 units into both walls.
#define TOD_SECRET_LIFT         14.0
#define TOD_SECRET_HALF_DEPTH   7.9
// v18.96b — SHOOT DETECTION IS A VIEW RAY, not the mesh. A 28-unit bear's
// bullet hull is a few pixels at range (user: "its clip or shootable area is
// tiny"), and the ice / fire staffs are PROJECTILES that never raise the
// script_model "damage" notify at all (user: "had to use lightning"). So
// every player's weapon_fired runs a ray from the eye along the view: a bear
// within TOD_SECRET_RAY_R of that ray, in front, within range and in line of
// sight, is hit — whatever the weapon. The engine notify stays as a second
// lane (a splash that lands still counts; a MELEE never did — the bear has no
// hit collision — and has its own lane since 2026-09-24, see MELEE_REACH).
#define TOD_SECRET_RAY_R        40
#define TOD_SECRET_RAY_LEN      4096
// 2026-09-24 — A BLADE COUNTS TOO (lead tester: "Slasher knife weapons can't hit
// the teddy bear"). Blades never raise weapon_fired, and the stock bear model
// has NO hit collision (t7_props_zombie.gdt: BulletCollisionLOD "None",
// CollisionMap ""), so a swing could never land on the engine lane either —
// that lane only ever caught splash. The Cyber Teddy (v19.64) keeps
// BulletCollisionLOD "None" on purpose: bullets pass through it as before.
// A swing now counts when a live bear is within TOD_SECRET_MELEE_REACH of the
// eye, inside the swing's cone, and in line of sight. The engine's melee
// notifies (stock's Gravity Spikes and riot shield listen for weapon_melee on
// a held melee weapon's swing) wake it. The floor-20 bear sits on the hoop
// lintel, ~190u above a standing eye, out of reach on purpose: that one is a
// shot (the slasher carries a sidearm at every tier).
#define TOD_SECRET_MELEE_REACH  120
#define TOD_SECRET_MELEE_DOT    0.5    // cos 60: the bear is in front of the swing

function init()
{
	level.tod_secret_found = 0;
	level.tod_secret_done = false;
	level thread place_bears();
	callback::on_spawned( &shot_watch );   // v18.96b: the view-ray lane, one per player
}

function place_bears()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	zs = tod_breather_data::breather_zs();   // [3648, 7488, 11328, 15168]
	spots = [];
	// Surface heights + TOD_SECRET_LIFT (the pivot is the bear's centre).
	// #0 BASE (v18.96f, user: "face the power hallway standing on floor up against
	// the wall"): back to the east end wall (inner face x=1620, 'power hall wall
	// E'), beside the switch (the v19.69 Grid Terminal panel, x 1608..1620,
	// y -495..-433 - POWER_TERM keeps it 8+ clear of this spot: LOCKSTEP, move
	// both or neither), facing WEST down the hall. Floor top z=0.
	spots[ 0 ] = spot( ( 1620 - TOD_SECRET_HALF_DEPTH, -520, 0 + TOD_SECRET_LIFT ), ( 0, 270, 0 ), "base power hall" );
	// #1 FLOOR 10 (user: "against a wall standing on the floor"): on the lounge
	// floor, back to the outer long wall's sill (inner face x=-800, the even
	// frame's mirror of 'wall E'), in the north bay (y between mullion b at
	// -814 and the N wall at -992), facing EAST into the room.
	spots[ 1 ] = spot( ( -800 + TOD_SECRET_HALF_DEPTH, -900, zs[ 0 ] + TOD_SECRET_LIFT ), ( 0, 90, 0 ), "floor 10 lounge floor" );
	// #2 FLOOR 20: standing on the second gantry hoop's lintel (top = floor +
	// 240), facing the room (+Y).
	spots[ 2 ] = spot( ( -704, -1222, zs[ 1 ] + TOD_SECRET_HOOP_TOP + TOD_SECRET_LIFT ), ( 0, 180, 0 ), "floor 20 spur hoop" );

	level.tod_secret_bears = [];
	dev_log( "INIT model=" + TOD_SECRET_MODEL + " rev=" + TOD_SECRET_REVISION + " lift=" + TOD_SECRET_LIFT + " half_depth=" + TOD_SECRET_HALF_DEPTH );
	for ( i = 0; i < spots.size; i++ )
	{
		b = Spawn( "script_model", spots[ i ].org );
		if ( !isdefined( b ) )
		{
			dev_log( "bear " + i + " (" + spots[ i ].label + ") FAILED to spawn — entity pool" );
			continue;
		}
		b SetModel( TOD_SECRET_MODEL );
		b.angles = spots[ i ].ang;
		b.tod_secret_idx = i;
		b.tod_secret_label = spots[ i ].label;
		level.tod_secret_bears[ i ] = b;
		b thread bear_watch( i );
		dev_log( "bear " + i + " placed at " + spots[ i ].org + " (" + spots[ i ].label + ")" );
	}
}

function spot( org, ang, label )
{
	s = SpawnStruct();
	s.org = org;
	s.ang = ang;
	s.label = label;
	return s;
}

// self = the bear. The engine raises "damage" on a SetCanDamage'd script_model
// for bullets, melee and splash alike; only a PLAYER's hit counts.
function bear_watch( idx )
{
	level endon( "end_game" );
	self endon( "death" );

	self SetCanDamage( true );
	self.health = 100000;   // never let a big hit "kill" the entity out from under the watcher (stock barricade rule)
	for ( ;; )
	{
		self waittill( "damage", amount, attacker, dir, point, mod );
		if ( IS_TRUE( level.tod_secret_done ) )
			return;
		if ( !isdefined( attacker ) || !isplayer( attacker ) )
		{
			dev_log( "bear " + idx + " hit by a non-player (" + ( ( isdefined( mod ) ) ? mod : "?" ) + "), ignored" );
			continue;
		}
		if ( IS_TRUE( level.tod_spire_active ) )
		{
			dev_log( "bear " + idx + " hit after ascension, refused (the tower is torn down)" );
			return;
		}
		break;
	}
	self bear_found( idx, attacker );
}

// self = a player (callback::on_spawned). ONE watcher per player for the
// match — the latch survives respawns (on_spawned fires again).
function shot_watch()
{
	if ( IS_TRUE( self.tod_secret_shot_watch ) )
		return;
	self.tod_secret_shot_watch = true;
	self thread shot_watch_run();
	// THE MELEE LANE (2026-09-24): one plain waittill loop per melee notify.
	// NOT util::waittill_any_return — it adds endon("death"), which would end
	// this once-per-match watcher at the player's first death for good.
	melees = array( "weapon_melee", "weapon_melee_power", "weapon_melee_power_left", "weapon_melee_charge", "weapon_melee_juke" );
	foreach ( note in melees )
		self thread melee_watch( note );
}

// self = a player. Lives for the match (no death endon — see shot_watch).
function melee_watch( note )
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( note );
		if ( IS_TRUE( level.tod_secret_done ) )
			return;
		if ( !isdefined( level.tod_secret_bears ) )
			continue;
		// Which notifies this engine actually sends for a blade, once each per
		// player: the evidence the next playtest needs if a swing still misses.
		if ( !isdefined( self.tod_secret_melee_seen ) )
			self.tod_secret_melee_seen = [];
		if ( !IS_TRUE( self.tod_secret_melee_seen[ note ] ) )
		{
			self.tod_secret_melee_seen[ note ] = true;
			w = self GetCurrentWeapon();
			dev_log( "melee: first " + note + " from player " + self GetEntityNumber() + " weapon=" + ( ( isdefined( w ) && isdefined( w.name ) ) ? w.name : "?" ) );
		}
		bear = self melee_hits_bear();
		if ( isdefined( bear ) )
			bear thread bear_found( bear.tod_secret_idx, self );
	}
}

// self = the player who just swung. -> the first live bear within reach, in
// front of the swing and in line of sight.
function melee_hits_bear()
{
	eye = self GetEye();
	fwd = AnglesToForward( self GetPlayerAngles() );
	foreach ( bear in level.tod_secret_bears )
	{
		if ( !isdefined( bear ) || IS_TRUE( bear.tod_secret_hit ) )
			continue;
		v = bear.origin - eye;
		d = Length( v );
		if ( d > TOD_SECRET_MELEE_REACH * 2 )
			continue;   // not even close: say nothing
		if ( d > TOD_SECRET_MELEE_REACH )
		{
			dev_log( "melee: bear " + bear.tod_secret_idx + " out of reach (" + int( d ) + "u > " + TOD_SECRET_MELEE_REACH + ")" );
			continue;
		}
		if ( d > 1 && VectorDot( VectorNormalize( v ), fwd ) < TOD_SECRET_MELEE_DOT )
		{
			dev_log( "melee: bear " + bear.tod_secret_idx + " in reach (" + int( d ) + "u) but behind the swing" );
			continue;
		}
		if ( !BulletTracePassed( eye, bear.origin, false, self ) )
		{
			dev_log( "melee: bear " + bear.tod_secret_idx + " in reach but line of sight blocked" );
			continue;
		}
		dev_log( "melee: bear " + bear.tod_secret_idx + " HIT at " + int( d ) + "u" );
		return bear;
	}
	return undefined;
}

function shot_watch_run()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "weapon_fired" );
		if ( IS_TRUE( level.tod_secret_done ) )
			return;
		if ( !isdefined( level.tod_secret_bears ) )
			continue;
		bear = self ray_hits_bear();
		if ( isdefined( bear ) )
			bear thread bear_found( bear.tod_secret_idx, self );
	}
}

// self = the player who just fired. -> the first live bear on the view ray.
function ray_hits_bear()
{
	eye = self GetEye();
	fwd = AnglesToForward( self GetPlayerAngles() );
	foreach ( bear in level.tod_secret_bears )
	{
		if ( !isdefined( bear ) || IS_TRUE( bear.tod_secret_hit ) )
			continue;
		v = bear.origin - eye;
		along = VectorDot( v, fwd );
		if ( along < 16 || along > TOD_SECRET_RAY_LEN )
			continue;
		perp = Length( v - fwd * along );
		if ( perp > TOD_SECRET_RAY_R )
			continue;
		// In line of sight — a bear behind a wall on the same bearing is not a hit.
		if ( !BulletTracePassed( eye, bear.origin, false, self ) )
		{
			dev_log( "ray: bear " + bear.tod_secret_idx + " on the bearing (perp " + int( perp ) + ") but line of sight blocked" );
			continue;
		}
		dev_log( "ray: bear " + bear.tod_secret_idx + " HIT at " + int( along ) + "u, perp " + int( perp ) );
		return bear;
	}
	return undefined;
}

// self = the bear. Both lanes (the engine notify, the view ray) land here;
// the latch makes the first one the only one.
function bear_found( idx, attacker )
{
	if ( IS_TRUE( self.tod_secret_hit ) )
		return;
	self.tod_secret_hit = true;
	org = self.origin;
	level.tod_secret_found++;
	dev_log( "bear " + idx + " (" + self.tod_secret_label + ") shot by player " + attacker GetEntityNumber() + " — " + level.tod_secret_found + "/" + TOD_SECRET_COUNT );

	// The tell: the hit zap and the laugh from the bear (everyone hears where);
	// the rise, the hover and the flight carry the rest (bear_fly_away).
	tod_perk_scatter::play_sound_at_origin( org, TOD_SECRET_HIT, 4 );
	tod_perk_scatter::play_sound_at_origin( org, TOD_SECRET_LAUGH, TOD_SECRET_LAUGH_SECS );
	last = ( level.tod_secret_found >= TOD_SECRET_COUNT );
	level thread bear_fly_away( self, last );
	if ( !last )
		return;

	// THE THIRD BEAR — the music dies NOW, under the laugh; the bear leaves;
	// then the 3 s of true silence; then the song (ee_song_start's lead is the
	// animation's length, the gap is its own). The sting plays at the departure.
	level.tod_secret_done = true;
	ok = tod_atmosphere::ee_song_start( TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS );
	dev_log( "all " + TOD_SECRET_COUNT + " bears found — song " + ( ( ok ) ? "ARMED (silence, flight, gap, then the song)" : "REFUSED by the channel (already played)" ) );
}

// THE RISE AND THE FLIGHT. `last` = the third bear: the sting for everyone
// at the departure (the song follows after the gap).
function bear_fly_away( bear, last )
{
	level endon( "end_game" );

	if ( !isdefined( bear ) )
		return;
	// The spin: one call over the whole exit, accelerating for all of it.
	bear RotateYaw( TOD_SECRET_SPIN_DEG, TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS, TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS, 0 );
	// The rise: slow, and itself accelerating, under the laugh.
	bear MoveZ( TOD_SECRET_RISE_Z, TOD_SECRET_RISE_SECS, TOD_SECRET_RISE_SECS, 0 );
	wait TOD_SECRET_RISE_SECS;
	if ( !isdefined( bear ) )
		return;
	// The launch: burst, zap, the sting on the last one, then up and away
	// (the spin is still ramping through it).
	tod_perk_scatter::derez_burst( bear.origin );
	tod_perk_scatter::play_sound_at_origin( bear.origin, TOD_SECRET_HIT, 4 );
	if ( IS_TRUE( last ) )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
				players[ i ] PlayLocalSound( TOD_SECRET_STING );
		}
	}
	away = ( bear.origin[ 0 ], bear.origin[ 1 ], 0 );
	if ( Length( away ) < 1 )
		away = ( 1, 0, 0 );
	away = VectorNormalize( away );   // outward from the tower's core
	dest = bear.origin + away * TOD_SECRET_FLY_OUT + ( 0, 0, TOD_SECRET_FLY_Z );
	bear MoveTo( dest, TOD_SECRET_FLY_SECS, TOD_SECRET_FLY_SECS * 0.7, 0 );
	wait TOD_SECRET_FLY_SECS;
	dev_log( "bear " + bear.tod_secret_idx + " flew away" );
	if ( isdefined( bear ) )
		bear Delete();
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_SECRET] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
