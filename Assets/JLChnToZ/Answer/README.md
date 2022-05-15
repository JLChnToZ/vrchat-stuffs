# Answer

So... what is this? This is the *ANSWER* of building VRChat world on both PC and Quest platform with the care of synchronization between them and unsupported gimmicks.

And then maybe you will ask what does it mean, then I will tell you that there are plenty of stuffs that is uncapable to run within Quest clients and you want to disable them when you build a Quest version of your world, but if you mark them "Editor Only" or even remove them completely for Quest build, you will find out your world's gimmick synchronization likely to be messed up when there are both PC and Quest users joined the same instance.

I try to investigate for the reason of this, and finally realized because under the hood VRChat uses Photon to handle networking stuffs, and it just smashed everything need to sync into a list. This is not a problem if users loaded the same build because the list are the same between them, BUT if they loaded different builds (For example, PC and shimmed down Quest build), the list is different.

Lets say you have objects `1 2 3 4 5` in a world needs to be synced, but object 3 is unsupported in Quest and you want to skip it, you deleted or tagged it "Editor Only", then the sync list becomes `1 2 4 5` but not `1 2 <null> 4 5` under the hood. When user from both platform joins, and Quest client trying to get the object 4's state (the 3rd of the list) from the friend's PC client, becuase it is missing something so the PC client will instead returns object 3's (the 3rd of the list) state, and the result is very noticable: the PC user holding object 3 and Quest user *may* sees it is holding object 4 instead (Actually it depends, sometimes it will not even shows anything).

This tool is very simple, it is a automatic switcher on build, it removes any objects you don't want during building unspported platform, but retains necessary components to "place holds" the internal list. Here are 3 kinds of behaviours it supports:
1. **Inactive Game Object** - Inactives this game object and its children when building to unsupported platform. Also removes components that don't affects synchronization.
2. **Remove Children Components Only** - Removes components that don't affects synchronization in this game object and its children when building to unsupported platform.
3. **Remove Self Components Only** - Removes components that don't affects synchronization in this game object when building to unsupported platform. Children objects and its components will retain as-is.

To use it, just add the "Sync Friendly Platform Selector" to the game object inspector and it will do the thing when you build/test/upload your world.
You can use this tool along side with other third party tool such as Easy Quest Switch, but you don't need to use both for same object.