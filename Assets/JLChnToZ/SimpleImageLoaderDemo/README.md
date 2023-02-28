Simple Image Loader Demo
========================

This is a simple demo on new image loading API and the auto binder attribute.
In the source code, I demonstrates how to use that attribute at `urlInputField` field at line 15-16, which will statically auto binds `onEndEdit` event to `_UpdateUrl` in current udon script during build; the other parts are demonstrating how to load and display external image from user input.

The attribute and handler script is at [Assets/JLChnToZ/Common/UnityEventBinder.cs](../Common/UnityEventBinder.cs), which is the location the script should be placed (to avoid conflicts when anyone want to include this file in their distrubuted gimmick assets).