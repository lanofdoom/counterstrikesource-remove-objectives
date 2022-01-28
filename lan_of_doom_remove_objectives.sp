#include <cstrike>
#include <sdktools>
#include <sourcemod>

public const Plugin myinfo = {
    name = "Remove Objectives", author = "LAN of DOOM",
    description = "Removes objectives at round start", version = "1.0.0",
    url = "https://github.com/lanofdoom/counterstrike-remove-objectives"};

static ConVar g_remove_objectives_cvar;
static bool g_objectives_removed = false;

static const char kBombEntityName[] = "weapon_c4";
static const char kBombTargetEntityName[] = "func_bomb_target";
static const char kDefusalKitEntityName[] = "item_defuser";
static const char kDefusalKitStoreName[] = "defuser";
static const char kHasDefuserPropertyName[] = "m_bHasDefuser";
static const char kHostageEntityName[] = "hostage_entity";
static const char kHostageRescueEntityName[] = "func_hostage_rescue";
static const char kPlantedBombEntityName[] = "planted_c4";

//
// Logic
//

static void UpdateEntities(const char[] classname, const char[] action) {
  int index = FindEntityByClassname(INVALID_ENT_REFERENCE, classname);
  while (index != INVALID_ENT_REFERENCE) {
    AcceptEntityInput(index, action);
    index = FindEntityByClassname(index, classname)
  }
}

static void EnableObjectives() {
  UpdateEntities(kBombTargetEntityName, "Enable");
  UpdateEntities(kHostageRescueEntityName, "Enable");
}

static void DisableObjectives() {
  UpdateEntities(kBombEntityName, "Kill");
  UpdateEntities(kHostageEntityName, "Kill");
  UpdateEntities(kPlantedBombEntityName, "Kill");
  UpdateEntities(kDefusalKitEntityName, "Kill");
  UpdateEntities(kBombTargetEntityName, "Disable");
  UpdateEntities(kHostageRescueEntityName, "Disable");

  for (int client = 1; client <= MaxClients; client++) {
    if (!IsClientInGame(client)) {
      continue;
    }

    if (IsPlayerAlive(client)) {
      SetEntProp(client, Prop_Send, kHasDefuserPropertyName, false);
    }

    int entity = GetPlayerWeaponSlot(client, CS_SLOT_C4);
    if (entity == INVALID_ENT_REFERENCE) {
      continue;
    }

    AcceptEntityInput(entity, "Kill");
  }
}

//
// Hooks
//

static Action OnRoundBoundary(Event event, const char[] name,
                              bool dont_broadcast) {
  if (GetConVarBool(g_remove_objectives_cvar)) {
    DisableObjectives();
    g_objectives_removed = true;
  } else {
    EnableObjectives();
    g_objectives_removed = false;
  }

  return Plugin_Continue;
}

//
// Forwards
//

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason) {
  if (!g_objectives_removed) {
    return Plugin_Continue;
  }

  if (reason == CSRoundEnd_HostagesNotRescued) {
    reason = CSRoundEnd_Draw;
    return Plugin_Changed;
  }

  if (reason == CSRoundEnd_TargetSaved) {
    reason = CSRoundEnd_Draw;
    return Plugin_Changed;
  }

  return Plugin_Continue;
}

public Action CS_OnBuyCommand(int client, const char[] weapon) {
  if (!g_objectives_removed) {
    return Plugin_Continue;
  }

  if (StrEqual(weapon, kDefusalKitStoreName)) {
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) {
  if (!g_objectives_removed) {
    return;
  }

  if (StrEqual(classname, kBombEntityName)) {
    AcceptEntityInput(entity, "Kill");
  }
}

public void OnPluginStart() {
  g_remove_objectives_cvar =
      CreateConVar("sm_lanofdoom_remove_objectives", "1",
                   "If true, objectives are removed at round start.");

  HookEvent("round_end", OnRoundBoundary);
  HookEvent("round_start", OnRoundBoundary);
}