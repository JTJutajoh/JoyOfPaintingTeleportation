# Joy Of Painting Teleportation Addon  
  
This addon for [Merlord](https://next.nexusmods.com/profile/Merlord?gameId=100)'s **[Joy Of Painting](http://https://www.nexusmods.com/morrowind/mods/53036)** allows you to enchant paintings and use them as portals to return to the exact spot where they were painted later.  
You can make a painting of a spot/an NPC you want to revisit later. Or cover a wall with your paintings as a portal hub.  
  
### Requirements  
The [original mod](https://www.nexusmods.com/morrowind/mods/53036) and all of its requirements.  
  
## How to Use  
### Enchanting a painting  
Select a completed painting and choose the **"View Painting"** option. If the painting is eligible to be enchanted, there will be an "Enchant" button that opens a new section in the UI that works similarly to vanilla Morrowind item enchanting.    
  
The enchant chance is calculated based on (More details in the MCM):  

- Enchant skill
- Painting skill _(at the time of painting!)_ as a fraction of the highest detail level of the art style/medium
- Strength of the trapped soul used  
    

_Alternatively_, you can set the **minimum success chance** to 100% in the MCM and disable the RNG  
  
### Teleporting  
Once a painting has been enchanted, there will be a **"Recall"** button on the "View Painting" menu that allows you to instantaneously return to the exact location where it was painted. Your orientation is rotated to match mostly eye level paintings.  
  
  
Check the MCM to fine-tune the behavior of the mod. There are a lot of settings to tweak the balance if you think it's too OP to have a bunch of portals in your pocket.  
  
  
### Compatibility  
Mod is purely MWSE Lua and pluginless so there **_should_ be no compatibility issues**. Please let me know if you think you've found one.  
  
Has a compatibility patch for [**Seph's Inventory Decorator**](https://www.nexusmods.com/morrowind/mods/50582). Enchanted paintings will try to match the appearance of enchanted equipment as defined by that mod.  
Note that paintings' icons will only be updated after the next save/load.  
If you do not have that mod installed, there will be settings in the MCM that mimic it for paintings only.  
  
Some UI retextures might not look great with the new UI, especially if they have a high transparency. It's built for vanilla so YMMV.  
  
  
### Adding/Removing  
**Safe to add** to an ongoing save. Paintings made before adding this mod will work fine. The only thing they're missing is what the Painting skill was when they were painted, so the mod assumes 100 Painting skill for old paintings to err on the side of making them easier.  
  
**_Should_ be safe to remove** from a save. This is my first Morrowind mod so I can't guarantee, but as far as I know the mod isn't adding/changing any data or scripts that should cause issues if removed.