#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\zm\_zm_perks;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perk_wisp_tea.gsh;

#precache("client_fx", WISP_TEA_MACHINE_LIGHT_FX);
#precache("client_fx", WISP_TEA_WISP_FX);
#precache("client_fx", WISP_TEA_WISP_TRAIL_FX);

#namespace zm_perk_wisp_tea;

REGISTER_SYSTEM("zm_perk_wisp_tea", &__init__, undefined)

function __init__()
{
	zm_perks::register_perk_clientfields(WISP_TEA_SPECIALTY, &wisp_tea_client_field_func, &wisp_tea_code_callback_func);
	zm_perks::register_perk_effects(WISP_TEA_SPECIALTY, WISP_TEA_MACHINE_LIGHT_FX_NAME);
	zm_perks::register_perk_init_thread(WISP_TEA_SPECIALTY, &init_wisp_tea);
}

function init_wisp_tea()
{
	if(IS_TRUE(level.enable_magic))
	{
		level._effect[WISP_TEA_MACHINE_LIGHT_FX_NAME] = WISP_TEA_MACHINE_LIGHT_FX;		
	}	
}

function wisp_tea_client_field_func()
{
	clientfield::register("clientuimodel", WISP_TEA_CLIENTFIELD, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT);

	clientfield::register("scriptmover", "wispTeaWispFX", VERSION_SHIP, 1, "int", &wispTeaWispFX, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
}

function wisp_tea_code_callback_func() {}

function wispTeaWispFX(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	switch(newVal)
	{
		case 0:
		{
			if(isdefined(self.wispFX))
			{
				StopFX(localClientNum, self.wispFX);
				StopFX(localClientNum, self.wispTrailFX);

				wait(3);

				DeleteFX(localClientNum, self.wispFX);
				DeleteFX(localClientNum, self.wispTrailFX);
				self.wispFX = undefined;
				self.wispTrailFX = undefined;
			}
			
			break;
		}
		case 1:
		{
			if(!isdefined(self.wispFX))
			{
				self.wispFX = PlayFXOnTag(localClientNum, WISP_TEA_WISP_FX, self, "tag_wispfx");
				self.wispTrailFX = PlayFXOnTag(localClientNum, WISP_TEA_WISP_TRAIL_FX, self, "tag_wispfx");
			}

			break;
		}
			
	}
}