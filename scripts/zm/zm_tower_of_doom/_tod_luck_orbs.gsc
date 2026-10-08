// Luck delivery. Rewards live in bounded server queues until their visible
// mover reaches its owner. The callback is the only route back to the bar;
// this leaf module never imports upgrades/powerups/luck (no import cycle).
#using scripts\shared\callbacks_shared;
#insert scripts\shared\shared.gsh;
#precache( "model", "tag_origin" );
#precache( "fx", "tod/fx_luck_soul" );

#define TOD_LUCK_ORB_STEP        0.05
#define TOD_LUCK_ORB_ACTIVE      6   // per player: at most 24 invisible movers
#define TOD_LUCK_ORB_PENDING    64   // per player; overflow combines queued value
#define TOD_LUCK_ORB_RELEASE     0.25
#define TOD_LUCK_ORB_MIN_LIFE    0.45
#define TOD_LUCK_ORB_RADIUS     12
#define TOD_LUCK_ORB_SPEED     650
#define TOD_LUCK_ORB_RELEASE_SFX_MS  200
#define TOD_LUCK_ORB_ARRIVE_SFX_MS   150

#namespace tod_luck_orbs;

function log( msg )
{
    if ( !IS_TRUE( level.tod_dev ) ) return;
    line = "[TOD_LUCK_ORB] ms=" + GetTime() + " " + msg;
    /# PrintLn( line ); #/
}

function init( receive_fn )
{
    // Follow the map's proven server FX lane (_tod_rampage): precache + zone
    // asset + level._effect handle. The older literal PlayFXOnTag call had no
    // visible result in the user's 2026-09-23 log despite 189 arrivals.
    level._effect[ "tod_luck_soul" ] = "tod/fx_luck_soul";
    level.tod_luck_orb_receive = receive_fn;
    level.tod_luck_orb_slots = [];
    level.tod_luck_orb_seq = 0;
    callback::on_disconnect( &on_disconnect );
    level thread manager();
    level thread game_cleanup();
    log( "INIT rev=4 active_per_player=6 pending_per_player=64 panzer=killer orb_arrival_only=1 ordinary_kills=direct audio=origins_soul_box fx=" + level._effect[ "tod_luck_soul" ] );
}

function slot_for( player )
{
    index = player GetEntityNumber();
    slot = level.tod_luck_orb_slots[ index ];
    if ( isdefined( slot ) && isdefined( slot.player ) && slot.player == player ) return slot;
    if ( isdefined( slot ) ) clear_slot( slot, "owner_replaced" );
    slot = SpawnStruct();
    slot.player = player;
    slot.index = index;
    slot.pending = [];
    slot.active = [];
    slot.hold = "";
    slot.retry_ms = 0;
    slot.release_sound_ms = 0;
    slot.arrive_sound_ms = 0;
    level.tod_luck_orb_slots[ index ] = slot;
    return slot;
}

// Synchronous reservation: the corpse/drop may disappear as soon as this
// returns. Never store that entity, only its copied world position.
function emit( player, amount, org, source )
{
    if ( !isdefined( player ) || !isplayer( player ) || !isdefined( amount ) || amount <= 0 ) return;
    if ( !isdefined( source ) ) source = "unspecified";
    if ( !isdefined( org ) )
    {
        org = player.origin + ( 0, 0, 32 );
        log( "SOURCE_FALLBACK p=" + player GetEntityNumber() + " source=" + source );
    }
    slot = slot_for( player );
    // Prolonged menus/death can accumulate many kills from lingering damage.
    // Keep their value, with one combined orb from the last queued source.
    // Ordinary bursts still get an individual orb for every reward.
    if ( slot.pending.size >= TOD_LUCK_ORB_PENDING )
    {
        job = slot.pending[ slot.pending.size - 1 ];
        job.amount += amount;
        job.count++;
        log( "MERGE id=" + job.id + " p=" + slot.index + " source=" + source + " added=" + amount + " total=" + job.amount + " count=" + job.count );
        return;
    }
    level.tod_luck_orb_seq++;
    job = SpawnStruct();
    job.id = level.tod_luck_orb_seq;
    job.amount = amount;
    job.source = source;
    job.org = org;
    job.count = 1;
    job.age = 0;
    job.created_ms = GetTime();
    job.slow_logged = false;
    job.host = undefined;
    job.release_sound_done = false;
    slot.pending[ slot.pending.size ] = job;
    log( "QUEUE id=" + job.id + " p=" + slot.index + " source=" + source + " amount=" + amount + " from=" + org + " pending=" + slot.pending.size );
}

function hold_reason( player )
{
    if ( !IsAlive( player ) ) return "dead";
    // Card odds were already rolled. Hold undelivered luck until the old bar
    // has been spent, including live-world co-op altar picks.
    if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen )
      || IS_TRUE( player.tod_solo_upg_active ) ) return "cards";
    return "";
}

function park( job )
{
    if ( !isdefined( job.host ) ) return;
    if ( IS_TRUE( job.audio_on ) )
    {
        job.host StopLoopSound();
        job.audio_on = false;
        log( "AUDIO_STOP id=" + job.id + " reason=host_parked" );
    }
    job.org = job.host.origin;
    job.host Delete();
    job.host = undefined;
}

function start_host( slot, job )
{
    if ( GetTime() < slot.retry_ms ) return false;
    job.host = Spawn( "script_model", job.org );
    if ( !isdefined( job.host ) )
    {
        slot.retry_ms = GetTime() + 1000;
        log( "RETRY id=" + job.id + " p=" + slot.index + " reason=spawn_failed amount=" + job.amount );
        return false;   // never award invisible luck on an allocation failure
    }
    job.host SetModel( "tag_origin" );
    job.host NotSolid();
    // Spawn/model needs one snapshot before attaching the looping native FX.
    // advance() waits one server tick using fx_ready before playing it.
    job.fx_ready = false;
    job.audio_on = false;
    job.visible_age = 0;
    log( "RELEASE id=" + job.id + " p=" + slot.index + " source=" + job.source + " amount=" + job.amount + " from=" + job.org + " queued_ms=" + ( GetTime() - job.created_ms ) );
    return true;
}

// Original pack audio, with softer aliases and bounded native voice counts.
// A resumed/recreated host restarts its travel loop but never its release cue.
function start_audio( slot, job )
{
    released = false;
    if ( !job.release_sound_done )
    {
        job.release_sound_done = true;
        if ( GetTime() >= slot.release_sound_ms )
        {
            job.host PlaySound( "tod_luck_soul_release" );
            slot.release_sound_ms = GetTime() + TOD_LUCK_ORB_RELEASE_SFX_MS;
            released = true;
        }
    }
    job.host PlayLoopSound( "tod_luck_soul_travel" );
    job.audio_on = true;
    log( "AUDIO_START id=" + job.id + " p=" + slot.index + " release=" + released + " travel_requested=1" );
}

function arrival_audio( slot )
{
    if ( GetTime() < slot.arrive_sound_ms ) return false;
    slot.arrive_sound_ms = GetTime() + TOD_LUCK_ORB_ARRIVE_SFX_MS;
    slot.player PlayLocalSound( "tod_luck_soul_arrive" );
    return true;
}

// One bounded step, called only for a connected, alive, non-menu owner.
// Arrival tests the mover's ACTUAL position, never the MoveTo destination or
// elapsed travel time. Teleporting owners are chased at a distance-scaled rate.
function advance( slot, job )
{
    if ( !isdefined( job.host ) )
    {
        start_host( slot, job );
        return false;
    }
    if ( !job.fx_ready )
    {
        PlayFXOnTag( level._effect[ "tod_luck_soul" ], job.host, "tag_origin" );
        log( "FX_ATTACH id=" + job.id + " p=" + slot.index + " fx=" + level._effect[ "tod_luck_soul" ] );
        start_audio( slot, job );
        job.fx_ready = true;
    }
    job.age += TOD_LUCK_ORB_STEP;
    job.visible_age += TOD_LUCK_ORB_STEP;
    target = slot.player GetEye() + ( 0, 0, -18 );
    dist = Distance( job.host.origin, target );
    // ARRIVAL REACH GROWS WITH THE PLAYER'S SPEED (bug review 2026-09-22,
    // F20): the chase step is clamped to the gap, so once close the mover
    // lands exactly on the previous tick's target and the next gap is one
    // tick of player movement — over 12 u for anyone sprinting, so the soul
    // trailed a sprinting player without ever paying. Reach = the radius plus
    // one tick of the player's own displacement.
    reach = TOD_LUCK_ORB_RADIUS + Length( slot.player GetVelocity() ) * TOD_LUCK_ORB_STEP;
    if ( job.visible_age >= TOD_LUCK_ORB_MIN_LIFE && dist <= reach )
    {
        // Remove the host before the callback. The manager removes the job in
        // this same no-wait step, so another tick can never pay it again.
        park( job );
        before = 0;
        if ( isdefined( slot.player.tod_luck_bar ) ) before = slot.player.tod_luck_bar;
        [[ level.tod_luck_orb_receive ]]( slot.player, job.amount );
        sound_played = arrival_audio( slot );
        log( "ARRIVE id=" + job.id + " p=" + slot.index + " source=" + job.source + " amount=" + job.amount + " before=" + before + " after=" + slot.player.tod_luck_bar + " distance=" + dist + " age=" + job.age + " count=" + job.count + " arrival_sound=" + sound_played );
        return true;
    }
    if ( job.visible_age < TOD_LUCK_ORB_RELEASE )
    {
        // Small lift makes close-range buys/melee kills readable too.
        job.host MoveTo( job.org + ( 0, 0, 12 ), TOD_LUCK_ORB_RELEASE );
        return false;
    }
    speed = TOD_LUCK_ORB_SPEED + 180 * job.age;
    if ( speed < dist * 1.5 ) speed = dist * 1.5;
    step = speed * TOD_LUCK_ORB_STEP;
    if ( step > dist ) step = dist;
    if ( dist > 0 )
    {
        dir = VectorNormalize( target - job.host.origin );
        job.host MoveTo( job.host.origin + VectorScale( dir, step ), TOD_LUCK_ORB_STEP );
    }
    if ( job.age > 15 && !job.slow_logged )
    {
        job.slow_logged = true;
        log( "SLOW id=" + job.id + " p=" + slot.index + " distance=" + dist + " amount=" + job.amount + " host=" + job.host.origin + " target=" + target + " player_velocity=" + slot.player GetVelocity() );
    }
    return false;
}

function tick_slot( slot )
{
    if ( !isdefined( slot ) ) return;
    if ( !isdefined( slot.player ) || !isplayer( slot.player ) )
    {
        clear_slot( slot, "owner_missing" );
        return;
    }
    reason = hold_reason( slot.player );
    if ( reason != slot.hold )
    {
        if ( slot.active.size + slot.pending.size > 0 )
            log( "HOLD p=" + slot.index + " reason=" + reason + " previous=" + slot.hold + " active=" + slot.active.size + " pending=" + slot.pending.size );
        slot.hold = reason;
    }
    if ( reason != "" )
    {
        foreach ( job in slot.active ) park( job );
        return;
    }
    next = [];
    foreach ( job in slot.active )
    {
        if ( !advance( slot, job ) ) next[ next.size ] = job;
    }
    slot.active = next;
    pending = [];
    foreach ( job in slot.pending )
    {
        if ( slot.active.size < TOD_LUCK_ORB_ACTIVE )
        {
            slot.active[ slot.active.size ] = job;
            start_host( slot, job );
        }
        else pending[ pending.size ] = job;
    }
    slot.pending = pending;
}

function manager()
{
    level endon( "end_game" );
    for ( ;; )
    {
        foreach ( slot in level.tod_luck_orb_slots ) tick_slot( slot );
        wait TOD_LUCK_ORB_STEP;
    }
}

function clear_slot( slot, reason )
{
    if ( !isdefined( slot ) ) return;
    amount = 0;
    foreach ( job in slot.active )
    {
        amount += job.amount;
        park( job );
    }
    foreach ( job in slot.pending ) amount += job.amount;
    if ( amount > 0 ) log( "CANCEL p=" + slot.index + " reason=" + reason + " amount=" + amount + " active=" + slot.active.size + " pending=" + slot.pending.size );
    slot.active = [];
    slot.pending = [];
    slot.player = undefined;
}

function on_disconnect()
{
    index = self GetEntityNumber();
    slot = level.tod_luck_orb_slots[ index ];
    if ( isdefined( slot ) ) clear_slot( slot, "disconnect" );
    level.tod_luck_orb_slots[ index ] = undefined;
}

function game_cleanup()
{
    level waittill( "end_game" );
    foreach ( slot in level.tod_luck_orb_slots ) clear_slot( slot, "end_game" );
}
