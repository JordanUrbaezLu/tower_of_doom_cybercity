// Thunder Smash: card-unlocked Stormbreaker tactical, Hellbound's bounded hop.
// Art request: docs/152. No weapon registrations; gmod7 overrides firstRaise.
#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#insert scripts\shared\shared.gsh;
#namespace tod_thunder_smash;

#precache( "eventstring", "tod_thunder_smash" );
#precache( "fx", "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit" );
#precache( "fx", "electric/fx_elec_burst_lg_z270_os" );
#precache( "fx", "_ZoekMeMaar/powerups/thunderstorm_effect" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_os" );
#precache( "fx", "zombie/fx_tesla_shock_zmb" );

#define TOD_SMASH_RADIUS 300
#define TOD_SMASH_IMPACT_MS 967
#define TOD_SMASH_ANIMATION_MS 2100
#define TOD_SMASH_ARC_HEIGHT 56
#define TOD_SMASH_ARC_DISTANCE 128
#define TOD_SMASH_ARC_STEP 0.05
#define TOD_SMASH_ARC_FLOOR_TOLERANCE 64
#define TOD_SMASH_ARC_FOOTPRINT_STEP 24
#define TOD_SMASH_ARC_MAX_ERROR 40
// Temporary playtest switch: useful in a normal match without enabling cheats.
#define TOD_SMASH_LOG 0   // 0 = SHIP (zeroed 2026-09-23 for the v19.50 publish; the module is retired from the map anyway)

function log( message )
{
    if ( !TOD_SMASH_LOG && !IS_TRUE( level.tod_dev ) ) return;
    line = "[TOD_THUNDER_SMASH] ms=" + GetTime() + " " + message;
    /# PrintLn( line ); #/
}

function init()
{
    // BO3 has NO LoadFX (that is the BO2/T6 idiom, and it boot-fatals here as
    // an unresolved external). In this engine a precached fx IS its path string
    // and PlayFX takes that string -- the map's own convention everywhere else
    // is level._effect[ key ] = "path" (see _tod_upgrades tod_thor_strike).
    level.tod_smash_ground = "dlc1/zmb_weapon/fx_wpn_spike_grnd_hit";
    level.tod_smash_burst = "electric/fx_elec_burst_lg_z270_os";
    level.tod_smash_bolt = "_ZoekMeMaar/powerups/thunderstorm_effect";
    level.tod_smash_strike = "dlc0/factory/fx_teleporter_elec_strike_os";
    level.tod_smash_shock = "zombie/fx_tesla_shock_zmb";
    callback::on_spawned( &on_spawned );
    log( "INIT revision=bound_hop_3 radius=300 impact_ms=967 cooldown=45/35/25" );
}

function on_spawned()
{
    self notify( "tod_smash_watch" );
    // A level-owned cast can clean up after death. A new life invalidates its
    // inventory snapshot so it cannot give yesterday's hammer to today's class.
    if ( isdefined( self.tod_smash_cast ) )
    {
        self.tod_smash_cast = undefined;
        self.tod_swap_busy = false;
        self EnableWeaponFire();
        self AllowMelee( true );
    }
    self.tod_smash_life = SpawnStruct();
    self.tod_smash_left = 0;
    self.tod_smash_total = 1;
    self.tod_smash_tactical = undefined;
    self.tod_smash_uses = 0;
    self thread watch();
}

function hammer( weapon )
{
    if ( !isdefined( weapon ) || !isdefined( weapon.name ) ) return false;
    return IsSubStr( weapon.name, "leviathan_k" ) || IsSubStr( weapon.name, "leviathan_up_k" );
}

function equipped( player )
{
    return isdefined( player.tod_class ) && player.tod_class == "slasher"
        && tod_classes::tier( player ) == 3 && hammer( player GetCurrentWeapon() );
}

function cooldown_ms( rank )
{
    if ( rank < 1 ) rank = 1;
    if ( rank > 3 ) rank = 3;
    return 55000 - rank * 10000;
}

function blocked( player )
{
    return !IsAlive( player ) || player laststand::player_is_in_laststand()
        || IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen )
        || IS_TRUE( player.tod_solo_upg_active )   // 2026-09-22 (F10): the co-op altar panel reads the same tactical button as its card switch
        || IS_TRUE( player.tod_tier_busy ) || player IsMantling() || player IsWallRunning()
        || player IsThrowingGrenade();
}

// Tactical ammo only: lethal grenades stay available. A refill while pinned is
// remembered. Never restore a removed/replaced grenade or resurrect one on spawn.
function tactical_pin( active )
{
    grenade = self.current_tactical_grenade;
    saved = self.tod_smash_tactical;
    if ( isdefined( saved ) && ( !active || grenade != saved.weapon ) )
    {
        if ( self HasWeapon( saved.weapon ) )
        {
            self SetWeaponAmmoClip( saved.weapon, saved.clip );
            self SetWeaponAmmoStock( saved.weapon, saved.stock );
        }
        self.tod_smash_tactical = undefined;
        saved = undefined;
    }
    if ( !active || !isdefined( grenade ) || grenade == level.weaponNone || !( self HasWeapon( grenade ) ) ) return;
    if ( !isdefined( saved ) )
    {
        saved = SpawnStruct();
        saved.weapon = grenade;
        saved.clip = 0;
        saved.stock = 0;
        self.tod_smash_tactical = saved;
    }
    clip = self GetWeaponAmmoClip( grenade );
    stock = self GetWeaponAmmoStock( grenade );
    if ( clip > saved.clip ) saved.clip = clip;
    if ( stock > saved.stock ) saved.stock = stock;
    self SetWeaponAmmoClip( grenade, 0 );
    self SetWeaponAmmoStock( grenade, 0 );
}

function watch()
{
    self endon( "disconnect" );
    self endon( "tod_smash_watch" );
    was_pressed = true;
    previous = GetTime();
    last_send = 0;
    last_sig = "";
    last_state = -1;
    for ( ;; )
    {
        wait 0.05;
        now = GetTime();
        elapsed = now - previous;
        previous = now;
        if ( !IS_TRUE( level.tod_upgrade_pause ) && self.tod_smash_left > 0 )
            self.tod_smash_left -= elapsed;
        if ( self.tod_smash_left < 0 ) self.tod_smash_left = 0;
        pressed = self SecondaryOffhandButtonPressed();
        edge = pressed && !was_pressed;
        was_pressed = pressed; // Menu presses never queue a cast on closing.
        rank = tod_upgrades::get_level( self, "thunder_smash" );
        on = equipped( self ) && IsAlive( self ) && !( self laststand::player_is_in_laststand() );
        self tactical_pin( on && rank > 0 );
        if ( edge && on && rank > 0 && !blocked( self ) && !IS_TRUE( self.tod_swap_busy )
            && !isdefined( self.tod_smash_cast ) && self.tod_smash_left <= 0 )
            self start( rank );
        else if ( edge && on && rank > 0 )
            log( "DENIED player=" + self GetEntityNumber() + " blocked=" + blocked( self ) + " swap=" + IS_TRUE( self.tod_swap_busy ) + " left_ms=" + self.tod_smash_left );
        state = 0;
        if ( on )
        {
            state = 1;
            if ( rank > 0 ) state = 2;
            if ( rank > 0 && self.tod_smash_left > 0 ) state = 3;
            if ( isdefined( self.tod_smash_cast ) ) state = 4;
        }
        seconds = int( ( self.tod_smash_left + 999 ) / 1000 );
        percent = int( 100 * ( 1 - self.tod_smash_left / self.tod_smash_total ) );
        if ( state == 4 ) percent = cast_percent( self.tod_smash_cast );
        uses = self.tod_smash_uses;
        if ( uses > 3 ) uses = 3;
        code = state + 8 * uses;
        if ( code != last_state )
        {
            log( "STATE player=" + self GetEntityNumber() + " state=" + state + " rank=" + rank + " uses=" + uses + " left_ms=" + self.tod_smash_left );
            last_state = code;
        }
        sig = code + ":" + percent + ":" + seconds;
        if ( sig != last_sig || now - last_send >= 1000 )
        {
            self send_hud( code, percent, seconds );
            last_send = now;
            last_sig = sig;
        }
    }
}

function send_hud( code, percent, seconds )
{
    // Argument 2 is the payload COUNT, never the state. Same contract as Mage.
    self LuiNotifyEvent( &"tod_thunder_smash", 3, code, percent, seconds );
}

function cast_percent( token )
{
    if ( !isdefined( token.raise_ms ) ) return 0;
    percent = int( 100 * ( GetTime() - token.raise_ms ) / TOD_SMASH_ANIMATION_MS );
    if ( percent < 0 ) percent = 0;
    if ( percent > 100 ) percent = 100;
    return percent;
}

function start( rank )
{
    original = self GetCurrentWeapon();
    root = original.rootWeapon;
    if ( !isdefined( root ) ) root = original;
    cast = GetWeapon( root.name, array( "gmod7" ) );
    if ( !isdefined( cast ) || cast == level.weaponNone || !cast_attachment( cast ) )
    {
        resolved = "undefined";
        attached = false;
        if ( isdefined( cast ) && cast != level.weaponNone )
        {
            resolved = cast.name;
            attached = cast_attachment( cast );
        }
        log( "DENIED reason=missing_cast_asset weapon=" + root.name + " resolved=" + resolved + " native_gmod7=" + attached + " expected_au=au_tod_thunder_smash_gmod7" );
        return;
    }
    token = SpawnStruct();
    token.id = GetTime();
    token.life = self.tod_smash_life;
    token.original = original;
    token.weapon = cast;
    token.clip = self GetWeaponAmmoClip( original );
    token.stock = self GetWeaponAmmoStock( original );
    token.camo = tod_classes::pap_camo_options( self, original );
    token.rank = rank;
    token.hit = false;
    self.tod_smash_cast = token;
    self.tod_swap_busy = true;
    self.tod_smash_total = cooldown_ms( rank );
    self.tod_smash_left = self.tod_smash_total;
    self DisableWeaponFire();
    self AllowMelee( false );
    // Same-root attachment mutation: taking AFTER giving removes both forms.
    self TakeWeapon( original );
    self GiveWeapon( cast, token.camo );
    self SetWeaponAmmoClip( cast, token.clip );
    self SetWeaponAmmoStock( cast, token.stock );
    self ShouldDoInitialWeaponRaise( cast, true );
    level thread perform( self, token );
    log( "START player=" + self GetEntityNumber() + " id=" + token.id + " weapon=" + original.name + " rank=" + rank + " cooldown_ms=" + self.tod_smash_total );
}

function owns_cast( player, token )
{
    return isdefined( player ) && isdefined( player.tod_smash_cast ) && player.tod_smash_cast == token
        && player.tod_smash_life == token.life;
}

function perform( owner, token )
{
    level endon( "end_game" );
    started = GetTime();
    motion = undefined;
    reason = "complete";
    // Let take/give settle before the FIRST switch, as the proven Mage raise
    // does. A same-frame switch can be swallowed by the engine. Only retry
    // during this bounded equip phase; never restart a cast already playing.
    wait 0.05;
    if ( !owns_cast( owner, token ) ) return;
    for ( i = 0; i < 10; i++ )
    {
        if ( blocked( owner ) || !( owner HasWeapon( token.weapon ) ) ) break;
        if ( i > 0 && owner GetCurrentWeapon() == token.weapon ) break;
        owner SwitchToWeaponImmediate( token.weapon );
        if ( !isdefined( token.raise_ms ) ) token.raise_ms = GetTime();
        wait 0.05;
        if ( !owns_cast( owner, token ) ) return;
    }
    if ( owner GetCurrentWeapon() != token.weapon || blocked( owner ) )
        reason = "equip_or_state";
    else
    {
        started = GetTime();
        log( "EQUIPPED id=" + token.id + " held=" + token.weapon.name + " native_gmod7=" + cast_attachment( owner GetCurrentWeapon() ) + " equip_wait_ms=" + ( started - token.id ) + " expected_first_raise=tod_thunder_smash_cast impact_ms=" + TOD_SMASH_IMPACT_MS );
        owner PlaySound( "tod_thor_zap" );
        motion = try_smash_arc( owner, token.id, 750 );
        for ( ;; )
        {
            if ( !owns_cast( owner, token ) ) return;
            if ( blocked( owner ) || !equipped( owner ) || owner GetCurrentWeapon() != token.weapon )
            { reason = "state_or_switch"; break; }
            elapsed = GetTime() - started;
            if ( isdefined( motion ) ) update_smash_arc( owner, motion, token.id );
            landed = owner IsOnGround();
            if ( isdefined( motion ) ) landed = landed && motion.airborne;
            if ( !token.hit && elapsed >= TOD_SMASH_IMPACT_MS && landed )
            {
                token.hit = true;
                owner.tod_smash_uses++;
                impact( owner, token );
            }
            if ( elapsed >= TOD_SMASH_ANIMATION_MS )
            {
                if ( !token.hit ) reason = "no_landing";
                break;
            }
            wait 0.05;
        }
    }
    finish( owner, token, reason );
}

function finish( owner, token, reason )
{
    if ( !owns_cast( owner, token ) ) return;
    current = owner GetCurrentWeapon();
    // Restore only our still-owned cast. Death/removal must never create a gun.
    if ( owner HasWeapon( token.weapon ) )
    {
        owner TakeWeapon( token.weapon );
        if ( IsAlive( owner ) && isdefined( owner.tod_class ) && owner.tod_class == "slasher" && tod_classes::tier( owner ) == 3 )
        {
            owner GiveWeapon( token.original, token.camo );
            owner SetWeaponAmmoClip( token.original, token.clip );
            owner SetWeaponAmmoStock( token.original, token.stock );
            owner ShouldDoInitialWeaponRaise( token.original, false );
            if ( ( current == token.weapon || !isdefined( current ) || current == level.weaponNone ) && !( owner laststand::player_is_in_laststand() ) )
            {
                // The return is another take/give: it needs the same frame
                // boundary as the cast. Keep ownership/locks until it settles.
                wait 0.05;
                if ( !owns_cast( owner, token ) ) return;
                if ( IsAlive( owner ) && owner HasWeapon( token.original ) && !( owner laststand::player_is_in_laststand() ) )
                owner SwitchToWeaponImmediate( token.original );
            }
        }
    }
    owner EnableWeaponFire();
    owner AllowMelee( true );
    owner.tod_swap_busy = false;
    owner.tod_smash_cast = undefined;
    if ( !token.hit ) owner.tod_smash_left = 0;
    log( "END player=" + owner GetEntityNumber() + " id=" + token.id + " reason=" + reason + " hit=" + token.hit + " left_ms=" + owner.tod_smash_left );
}

function impact( owner, token )
{
    origin = owner.origin + ( 0, 0, 8 );
    PlayFX( level.tod_smash_ground, origin );
    PlayFX( level.tod_smash_burst, origin );
    PlayFX( level.tod_smash_bolt, origin );
    for ( i = 0; i < 6; i++ )
    {
        offset = AnglesToForward( ( 0, i * 60, 0 ) ) * 140;
        trace = BulletTrace( origin, origin + offset, false, owner );
        PlayFX( level.tod_smash_strike, trace["position"] );
    }
    owner PlaySound( "tod_thor_clap" );
    owner PlaySound( "tod_thor_storm1" );
    Earthquake( 0.6, 0.7, origin, TOD_SMASH_RADIUS * 2 );
    round_hp = 100;
    if ( isdefined( level.zombie_health ) ) round_hp = level.zombie_health;
    targets = GetAIArray( "axis" );
    hits = 0;
    elites = 0;
    foreach ( victim in targets )
    {
        if ( !isdefined( victim ) || !IsAlive( victim ) || Distance( origin, victim.origin ) > TOD_SMASH_RADIUS ) continue;
        trace = BulletTrace( origin + ( 0, 0, 24 ), victim.origin + ( 0, 0, 24 ), false, owner );
        if ( trace["fraction"] < 1 ) continue;
        elite = tod_upgrades::is_boss_or_elite( victim ) || IS_TRUE( victim.tod_is_sprinter );
        damage = victim.health + 1;
        if ( elite ) { damage = int( round_hp * 2 * token.rank ); elites++; }
        if ( hits < 8 ) PlayFX( level.tod_smash_shock, victim.origin );
        // Same-frame, attacker-scoped raw damage; no Thor/Cleave recursion.
        victim.tod_smash_hit_ms = GetTime();
        victim.tod_smash_attacker = owner;
        // v19.38 LEECH DOES NOT STACK: a slam kill carried the held
        // Stormbreaker as its weapon, so LEECH paid one heal PER BODY. Same
        // persistent mark Thor's strike and a Cleave splash stamp (user
        // 2026-09-05: multi-kill healing "cant happen").
        victim.tod_no_leech = true;
        victim DoDamage( damage, victim.origin, owner, owner, "none", "MOD_IMPACT", 0, token.original );
        if ( isdefined( victim ) )
        {
            victim.tod_smash_hit_ms = undefined;
            victim.tod_smash_attacker = undefined;
        }
        hits++;
    }
    log( "IMPACT player=" + owner GetEntityNumber() + " id=" + token.id + " targets=" + hits + " elites=" + elites + " radius=" + TOD_SMASH_RADIUS + " elite_damage=" + int( round_hp * 2 * token.rank ) );
}

function arc_position( motion, u )
{
    return motion.start + motion.delta * u + ( 0, 0, 4 * TOD_SMASH_ARC_HEIGHT * u * ( 1 - u ) );
}

function arc_path_clear( owner, start, delta )
{
    angles = owner GetPlayerAngles();
    right = AnglesToRight( ( 0, angles[1], 0 ) );
    head_height = ( owner GetStance() == "crouch" ? 52 : 72 );
    test = SpawnStruct();
    test.start = start;
    test.delta = delta;
    // Sample the curved body corridor using the player's actual stance height.
    // Engine player collision stays active; these are not a replacement hull.
    for ( i = 0; i < 8; i++ )
    {
        a = arc_position( test, i / 8.0 );
        b = arc_position( test, ( i + 1 ) / 8.0 );
        foreach ( side in array( -18, 0, 18 ) )
        {
            foreach ( height in array( 2, head_height * 0.5, head_height ) )
            {
                offset = right * side + ( 0, 0, height );
                trace = BulletTrace( a + offset, b + offset, true, owner );
                if ( trace["fraction"] < 1 ) return false;
            }
        }
    }
    return true;
}

function try_smash_arc( owner, token, flight_ms )
{
    reason = "";
    if ( flight_ms < 250 ) reason = "late_launch";
    else if ( !( owner IsOnGround() ) ) reason = "airborne";
    else if ( owner GetStance() == "prone" ) reason = "prone";
    if ( reason != "" )
    {
        log( "ARC_SKIP id=" + token + " reason=" + reason );
        return undefined;
    }
    angles = owner GetPlayerAngles();
    forward = AnglesToForward( ( 0, angles[1], 0 ) );
    right = AnglesToRight( ( 0, angles[1], 0 ) );
    start = owner.origin;
    // Prefer forward travel; shorten it or jump in place when the path is tight.
    foreach ( distance in array( TOD_SMASH_ARC_DISTANCE, TOD_SMASH_ARC_DISTANCE * 0.5, 0 ) )
    {
        destination = start + forward * distance;
        // Hellbound stairs rise16 units per tread: a full arc can cross four.
        floor = BulletTrace( destination + ( 0, 0, TOD_SMASH_ARC_FLOOR_TOLERANCE + 8 ), destination - ( 0, 0, TOD_SMASH_ARC_FLOOR_TOLERANCE + 8 ), true, owner );
        if ( floor["fraction"] == 1 ) continue;
        if ( Abs( floor["position"][2] - start[2] ) > TOD_SMASH_ARC_FLOOR_TOLERANCE || floor["normal"][2] < 0.7 ) continue;
        if ( isdefined( floor["entity"] ) && ( IsActor( floor["entity"] ) || IsPlayer( floor["entity"] ) ) ) continue;
        destination = floor["position"] + ( 0, 0, 1 );
        supported = true;
        foreach ( offset in array( right * 18, right * -18, forward * 18, forward * -18 ) )
        {
            edge = BulletTrace( destination + offset + ( 0, 0, TOD_SMASH_ARC_FOOTPRINT_STEP + 8 ), destination + offset - ( 0, 0, TOD_SMASH_ARC_FOOTPRINT_STEP + 8 ), true, owner );
            if ( edge["fraction"] == 1 ) supported = false;
            else if ( edge["normal"][2] < 0.7 || Abs( edge["position"][2] - destination[2] ) > TOD_SMASH_ARC_FOOTPRINT_STEP ) supported = false;
            else if ( isdefined( edge["entity"] ) && ( IsActor( edge["entity"] ) || IsPlayer( edge["entity"] ) ) ) supported = false;
        }
        if ( !supported ) continue;
        delta = destination - ( start + ( 0, 0, 1 ) );
        if ( !arc_path_clear( owner, start + ( 0, 0, 1 ), delta ) ) continue;
        motion = SpawnStruct();
        motion.start = start + ( 0, 0, 1 );
        motion.delta = delta;
        motion.started = GetTime();
        motion.duration_ms = flight_ms;
        motion.airborne = false;
        motion.driving = true;
        motion.apex_logged = false;
        motion.max_rise = 0;
        motion.distance = distance;
        owner SetOrigin( motion.start ); // Stock _zm_jump_pad.gsc ground release.
        log( "ARC_START id=" + token + " origin=" + start + " distance=" + distance + " height=" + TOD_SMASH_ARC_HEIGHT + " duration_ms=" + flight_ms + " stance=" + owner GetStance() + " landing_dz=" + delta[2] );
        return motion;
    }
    log( "ARC_SKIP id=" + token + " reason=no_clear_arc_or_supported_landing" );
    return undefined;
}

function update_smash_arc( owner, motion, token )
{
    elapsed = GetTime() - motion.started;
    rise = owner.origin[2] - motion.start[2];
    if ( rise > motion.max_rise ) motion.max_rise = rise;
    if ( !( owner IsOnGround() ) && rise > 4 ) motion.airborne = true;
    if ( !motion.apex_logged && elapsed >= motion.duration_ms * 0.5 )
    {
        motion.apex_logged = true;
        log( "ARC_APEX id=" + token + " rise=" + rise + " max_rise=" + motion.max_rise + " travel=" + Distance2D( owner.origin, motion.start ) + " airborne=" + motion.airborne );
    }
    if ( !motion.driving ) return;
    if ( motion.airborne && owner IsOnGround() )
    {
        motion.driving = false;
        log( "ARC_LANDED id=" + token + " elapsed_ms=" + elapsed + " max_rise=" + motion.max_rise + " travel=" + Distance2D( owner.origin, motion.start ) );
        return;
    }
    if ( elapsed >= motion.duration_ms ) { motion.driving = false; return; }
    u = elapsed / motion.duration_ms;
    expected = arc_position( motion, u );
    if ( Distance( expected, owner.origin ) > TOD_SMASH_ARC_MAX_ERROR )
    {
        motion.driving = false;
        log( "ARC_RELEASE id=" + token + " reason=blocked_or_displaced error=" + Distance( expected, owner.origin ) );
        return;
    }
    // Aim for the next server-frame position, compensating for actual player
    // gravity over that interval. No gravity override or camera/angle changes.
    next_u = ( elapsed + TOD_SMASH_ARC_STEP * 1000 ) / motion.duration_ms;
    if ( next_u > 1 ) next_u = 1;
    target = arc_position( motion, next_u );
    velocity = ( target - owner.origin ) * ( 1.0 / TOD_SMASH_ARC_STEP );
    gravity = owner GetPlayerGravity();
    velocity += ( 0, 0, gravity * TOD_SMASH_ARC_STEP * 0.5 );
    if ( Length( velocity ) > 900 )
    {
        motion.driving = false;
        log( "ARC_RELEASE id=" + token + " reason=velocity_bound" );
        return;
    }
    owner SetVelocity( velocity );
}


function cast_attachment( weapon )
{
    return WeaponHasAttachment( weapon, "gmod7" );
}
