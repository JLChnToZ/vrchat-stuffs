# Pickupable Pool Manager

The purpose of this script is because there is limitation in VRChat SDK3, world creator cannot make an object with UDONs that can be instaniated, interactable or even synchronizable. The alternative way to make object acts like duplicatable is make use of VRC Object Pools, but without extra UDON script support, it is hard to synchronize the state and recycling. This script aims to solve these problems.

At the time of first user join, it will spawn a random instance wait for user to pick up. Once user picks up, this script will spawns another random one immediately unless there is no more pooled objects available. When the user leave the spawned object alone for a certain time (can be configurated), the object will return to the pool and wait for another user to pick up.

It is very easy to setup.
1. Attach the `UdonBehaviour` with the `PickablePoolManager` along with an object pool. You may use the available prefab as a starting point.
2. Pooled objects must be a child of the object pool GameObject in hierachy.
3. Attach `UdonBehaviour` with `PickableManager` to all pooled objects.
4. Setup the pooled objects' properties of `RigidBody`, `Collider` and `VRCPickup` components if you haven't done yet (these components should be added automatically at last step, if they have not been added).
5. Set the same initial position, scale and rotation to all pooled objecs, this is for users' convenience.
6. Set all pooled objects inactive or the runtime state of attached UDONs may be corrupted and cause it to not functioning, the script will set them active when it is needed.
7. Duplicate the pooled objects depends on how many instances you want for maximum in a world. Instead of directly duplication, I recommend to make the pooled objects with the scripts attached as a new prefab or prefab variant, and each pooled objects are the instances of the prefab, it will easier to modify its properties afterwards.
8. Click on the `Add all children with handlers to object pool` button in `PickablePoolManager` in Inspector panel, the pool is ready to use.
