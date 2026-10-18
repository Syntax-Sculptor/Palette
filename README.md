<p align="center">
  <img src="assets/logo.png" alt="Palette Logo" width="256">
</p>

<h1 align="center">Palette</h1>


> [!WARNING]
> Palette is currently under active development. While there are no glaring bugs and can be used for production, the API is subject to change as more updates come out.

https://github.com/user-attachments/assets/a982abbc-034d-4144-bd9b-c15a88069f06

---

**Palette** is a work-in-progress 2D particle engine library for The Binding of Isaac: Repentance+ built using the [REPENTOGON](https://repentogon.com/) script extender. Its features are inspired by Unity's [Shuriken Particle System](https://docs.unity3d.com/2022.3/Documentation/Manual/ParticleSystemModules.html).

Historically, Isaac's modding API has been extremely limited when it comes to particle effects. Traditionally, the primary function pertaining to particle effects provided is `Game:SpawnParticles`, which is used for various effects such as the gibs spawned when killing a monster. However, it provides very little customization.

Palette aims to fill in the gap by allowing modders to easily create and customize particle effects to create stunning visual effects with very little Lua involved. On top of that, it leverages several low-level rendering features that REPENTOGON exposes with performance in mind.

## Installing

Installing Palette is extremely simple!

1. Download the latest version of `palette.lua` [here](https://github.com/Syntax-Sculptor/Palette/releases/latest/download/palette.lua)
2. Save the Lua file anywhere inside your mod.
3. In `main.lua`, load the file using `include` and initialize it:

```lua
local TestMod = RegisterMod("Palette Test Mod", 1)
local Palette = include("test-mod-scripts.palette") -- Change the directory based on where you saved Palette.

Palette:Init(TestMod)
```

And you're done! To get started with using Palette, you can [check out the Wiki](https://github.com/Syntax-Sculptor/Palette/wiki)!

## Planned Features / Roadmap

**Planned Features**

- The ability to have particles render behind specific entities.
- The ability to configure particle shapes.
- The ability to have particles play proper animations.
- The ability to randomize particle properties
- A standalone desktop application that allows you to create, configure, and preview particle effects before exporting them to Lua.
- And more?


## Contribution Policy

Palette is currently in very early development. However, anyone is welcome to jump aboard and contribute! Before getting started, please follow these guidelines:

- Please open a GitHub Issue to discuss major features or architectural changes before implementation.
    - Generally speaking, this should be done for any major new features so you don't waste your time implementing a new feature that doesn't align with the library's vision.
    - You can also discuss it on the Palette thread inside of the Modding of Isaac Discord server.
- If any AI tools were used (Claude, Codex, etc.), please disclose its usage in the Pull Request.
    - Vibecoded Pull Requests that have not been reviewed, tested, or understood by you will be closed. You're expected to know your own code and it is not the maintainers job to do it for you.

## Special Thanks

- Syntax-Sculptor: Programmer
- los_sasikos: Logo artist
