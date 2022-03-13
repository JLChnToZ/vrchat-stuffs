# Color Picker for VRChat Worlds

This is a generic color picker component for use in VRChat SDK3 worlds. This color picker consists only 1 orb shaped handle and is able to pick all available display colors. The design is optimized for VR usage though, PC users should not very hard to use. This color picker is designed to integrate with other UDON gimmicks, you can easily to get/set the color the user picks with via UDON programs, or even get callbacks when user updates the color.

This color picker was originally designed for picking colors for AudioLink theme colors, but I want that full version to be unique and exclusively available for certain worlds but I also want to help the VRChat UDON community a bit, so I descided to publish this generic version.

The ready to use color picker component is located in Prefabs directory, drop it to your world and you can start to use it.

The main script is `ColorPickerHandle`. It is located at "Picker" object, your UDON should refer this object in order to integrate with the color picker.
It contains following properties in inspector:
- `Radius`, the palette radius, should be half of the scale of the "Palette" object.
- `Height`, the palette height, the height where the color is black.
- `Indicaor`, reference to the Indicator orb object, should not be changed.
- `Is Global`, enable this if you want the color to be synced between users.
- `Color`, default (initial color it picked).

Inside the script, you can access these properties and methods:
- `color`, the color it picks (UDON graph only)
  - `UpdateColor()`, the event should be called if you update the color via UDON graph.
- `SelectedColor`, the color it picks (UDONSharp only), can be updated by directly assign the color to this property.
- `RegisterCallback(UdonSharpBehaviour ub)`, Registers the callback, it will calls `ColorChanged` custom event of the target UDON when color updates locally or remotely.

This is licensed under MIT license. Although it is not required, please credit me if you integrate this component to your own world or gimmick and you think it is worth it, I will be appreciated!
