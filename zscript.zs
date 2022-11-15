version "4.8"

class CurseHandler : EventHandler {
    Array<Actor> cursedmobs; // List of cursed enemies.
    double cursechance; // 0.0 to 1.0, how likely are enemies to be cursed? 0.0 means never.
    double symbolchance; // 0.0 to 1.0, how likely is a powerup or custominventory to have a holy symbol next to it? 
    int symbolcap; // How many symbols are allowed to spawn per map?
    int nextRes; // When are we gonna try resurrecting again?

    override void OnRegister() {
        cursechance = CVar.GetCVar("nightlite_curse_chance").GetFloat(); //TODO: cvar these
        symbolchance = CVar.GetCVar("nightlite_symbol_chance").GetFloat();
        symbolcap = CVar.GetCVar("nightlite_symbol_cap").GetInt();
        nextRes = random(35 * 20, 35 * 60); 
    }

    override void WorldThingSpawned(WorldEvent e) {
        if (e.thing.bISMONSTER && e.thing.ResolveState("Raise") && frandom(0,1) <= cursechance) {
            // This thing *should* be resurrect-able, and it passed the curse chance check,
            // so let's add it to the cursedmobs list and give it the CurseMark.
            cursedmobs.push(e.thing);
            e.thing.GiveInventory("CurseMark",1);
        }
        
        if (e.thing is "PowerupGiver" || e.thing is "CustomInventory") {
            if (frandom(0,1) <= symbolchance && symbolcap != 0) {
                let symbol = e.thing.Spawn("HolySymbol",e.thing.pos);
                if (symbol) {
                    symbol.vel = (frandom(-4,4),frandom(-4,4),4);
                    if (symbolcap > 0) {
                        symbolcap -= 1;
                    }
                }
            }

        }
    }

    override void WorldTick() {
        if (Level.MapTime >= nextRes) {
            Array<Actor> toraise; // Queue up corpses to raise.
            for (int i = 0; i < cursedmobs.size(); i++) {
                let it = cursedmobs[i];
                if (it.bCORPSE && !it.InStateSequence(it.curstate, it.ResolveState("XDeath"))) {
                    if (cursedmobs[i].CanRaise()) {
                        toraise.push(cursedmobs[i]);
                    } else {
                        cursedmobs.delete(i); // If we can't raise it or it's gibbed, take it off the list.
                    }
                }
            }
            // Now, if the cursed mob list has more entries than the corpse list...
            if (cursedmobs.size() > toraise.size()) {
                // ...that must mean some of the cursed mobs are still alive, so we can resurrect everything in the corpse list.
                for (int i = 0; i < toraise.size(); i++) {
                    toraise[i].RaiseActor(toraise[i]);
                }
            }
            // Finally, set the next resurrection attempt time.
            nextRes += random(35 * 20, 35 * 60);
        }
    }
}

class CurseMark : Inventory {
    // Only responsible for altering damage from the HolySymbol.
    default {
        inventory.maxamount 1;
    }

    override void ModifyDamage(int dmg, Name mod, out int newdmg, bool passive, Actor inf, Actor src, int flags) {
        if(passive && mod == "HolySymbol") {
            newdmg = 1000000000; // splat
        }
    } 
}

class HolySymbol : Inventory {
    default {
        +Inventory.INVBAR;
        Inventory.Amount 1;
        Inventory.MaxAmount 10; // Good luck saving up this many!
        Inventory.PickupMessage "Found a holy symbol.";
        Inventory.Icon "HOLYA0";
    }

    override bool Use(bool pickup) {
        if (!pickup) {
            owner.A_Explode(5,256,XF_NOTMISSILE|XF_EXPLICITDAMAGETYPE,false,256,damagetype:"HolySymbol");
            owner.A_RadiusThrust(400,256,RTF_NOTMISSILE);
            return true;
        } else {
            return false;
        }
    }

    states {
        Spawn:
            HOLY A 8;
            HOLY A 2 Bright;
            Loop;
    }
}