# Cosmic Serpent

*Created by **Venkat Midhun Mareedu***

Cosmic Serpent is a snake game set in deep space. You steer a glowing star-snake, eat stars and chain combos. Twelve power-ups keep each run changing: Hyperdrive, Phase Shift, Gravity Well, Time Warp, Force Shield, Supernova, Wormhole, Molt, Stellar Surge, Stasis Field, Plasma Lance and Quantum.

## Controls

| Key | Action |
|---|---|
| Arrow keys / WASD | Steer |
| Esc / P | Pause (Esc on the game-over screen goes back to the menu) |
| Enter / Space | Launch or relaunch |
| M | Music on/off |
| Tab (or O) | Settings: master, music and sound-effect volume (saved automatically). The menu also has a clickable SETTINGS button |

## Install on Windows

**Requirements**
- Windows 10 or 11, 64-bit.
- A graphics card that supports Vulkan or Direct3D 12. Most GPUs from 2016 onward do. Keep your graphics drivers up to date.

**Steps**
1. Download `CosmicSerpent-windows-x86_64.zip`.
2. Right-click the zip, choose **Extract All…**, and pick a folder, for example `C:\Games\CosmicSerpent`.
3. Double-click **`CosmicSerpent.exe`** to play.
4. The game isn't code-signed, so Windows SmartScreen may show "Windows protected your PC". Click **More info**, then **Run anyway**. You only have to do this once.
5. Optional: to add a desktop shortcut, right-click `CosmicSerpent.exe` and choose **Send to → Desktop (create shortcut)**.

**Uninstall:** delete the folder. To also remove your high score, delete `%APPDATA%\Godot\app_userdata\Cosmic Serpent`.

## Install on Linux

**Requirements**
- A 64-bit (x86_64) distribution.
- Vulkan drivers:

| Distribution | GPU | Package |
|---|---|---|
| Arch | AMD | `vulkan-radeon` |
| Arch | Intel | `vulkan-intel` |
| Arch | NVIDIA | `nvidia-utils` |
| Ubuntu / Debian | AMD or Intel | `mesa-vulkan-drivers` |
| Ubuntu / Debian | NVIDIA | the proprietary driver |

**Steps**
```bash
tar -xzf CosmicSerpent-linux-x86_64.tar.gz
cd CosmicSerpent-linux-x86_64
./CosmicSerpent.x86_64
```

To add it to your application launcher, run this once from inside the extracted folder:
```bash
./install-desktop-entry.sh
```
It creates `~/.local/share/applications/cosmic-serpent.desktop`, which points at the current folder. If you move the folder, run it again.

**Uninstall:** run `rm ~/.local/share/applications/cosmic-serpent.desktop` and delete the folder. To also remove your high score, delete `~/.local/share/godot/app_userdata/Cosmic Serpent`.

## Troubleshooting

- **The game won't start, or you see a Vulkan error.** Update your graphics drivers. On Linux, install the Vulkan package from the table above and check it with `vulkaninfo --summary`, which comes from the `vulkan-tools` package.
- **Linux says "Permission denied".** Run `chmod +x CosmicSerpent.x86_64`.
- **The game runs on the wrong GPU on a hybrid-graphics laptop.** On Linux, launch it with `prime-run ./CosmicSerpent.x86_64` (NVIDIA). On Windows, go to Settings → Display → Graphics and set CosmicSerpent.exe to "High performance".

## Building from source

You need Godot 4.7.2 and its export templates. In the editor, install the templates with **Editor → Manage Export Templates**. Without the editor, extract `Godot_v4.7.2-stable_export_templates.tpz` into `~/.local/share/godot/export_templates/4.7.2.stable/`. Then build:

```bash
./build.sh
```

`build.sh` exports both platforms and writes the release archives to `build/`. To run the game from source without building, use `godot --path .`.

## Credits

**Created by Venkat Midhun Mareedu** ([@venkatmidhunmareedu](https://github.com/venkatmidhunmareedu)): game design and direction.

The Orbitron font is by Matt McInerney and is licensed under the SIL Open Font License 1.1 (see `assets/fonts/OFL.txt`). All other graphics, the sound effects and the music are generated in code when the game starts.
