# sotavpn

English | [Русский](README.ru.md)

> Run the [Sota Connect](https://sotavpn.net/) VPN client on NixOS — packaged properly, with a working `sotad` daemon and a TUN-ready firewall.

![License: Freeware](https://img.shields.io/badge/license-Freeware-blue.svg) ![Platform](https://img.shields.io/badge/platform-x86--64--linux-success)

Sota Connect ships as a prebuilt Arch package (`.pkg.tar.zst`) that assumes a regular FHS layout — `/usr/bin`, `/usr/libexec`, `/usr/lib`. None of that exists on NixOS. This module repackages it for the Nix store with `autoPatchelf`, wires up the `sotad` daemon as a hardened systemd service, and prepares the firewall for its TUN interface.

## Features

- 📦 **Nix-native packaging** — `autoPatchelf` + patched RPATHs, no FHS hacks, no `/opt` materialisation
- 🛡️ **Daemon as a service** — `sotad` runs as a hardened root systemd unit (TUN, routes, split-tunnel caps)
- 🧩 **Flutter GUI working out of the box** — bundled plugins `dlopen` cleanly; inert `libjvm` NEEDED entries stripped
- 🔒 **TUN-mode ready** — `tun` module and a firewall trusted interface for the tunnel

## Installation

Import the feature module and enable the service:

```nix
{
  imports = [
    ./sotavpn-module.nix
  ];

  services.sotavpn.enable = true;
}
```

Rebuild, then launch **Sota Connect** from your app menu (or run `sotavpn`). The `sotad` daemon starts automatically in the background:

```bash
sudo nixos-rebuild switch
```

## Updating

The tarball is fetched from a `-latest` URL, so its `sha256` is pinned in `sotavpn.nix`. When a new version ships, update the hash:

```bash
nix hash file --type sha256 <(curl -sL https://storage.sota.ac/api/v1/public/storage/sotavpn-latest-x64.pkg.tar.zst)
```

Or simply rebuild and let the error tell you the new hash:

```bash
sudo nixos-rebuild switch
```

## Options

| Option | Default | Description |
| --- | --- | --- |
| `services.sotavpn.enable` | `false` | Enable the sotavpn client and the background `sotad` daemon. The repo's feature module sets this to `true` on import. |
| `services.sotavpn.package` | built from `sotavpn.nix` | Override the Sota Connect package. |
| `services.sotavpn.tunInterface` | `"tun0"` | TUN device trusted by the firewall (already claimed by `services.happ` — change it if you run both). |

## The `libjvm` fix

The bundled Flutter JNI glue (`libdartjni.so`, `libgtk_plugin.so`) carries a `DT_NEEDED libjvm.so` reference. The shipped `native_assets.json` / `NativeAssetsManifest.json` are **empty** — there are no Java native assets at runtime — and the package's target distro (Arch) has no JVM either. The derivation strips the `libjvm` NEEDED entry so the plugins load cleanly without dragging in a ~300 MB JRE:

```bash
patchelf --remove-needed libjvm.so "$so"
```

## Security trade-offs

- `sotad` runs as **root with `NoNewPrivileges=true`** and only `CAP_NET_ADMIN CAP_NET_RAW CAP_DAC_READ_SEARCH CAP_SYS_PTRACE` — it brings up the TUN interface, sets routes, captures packets (window title detection for split-tunnel) and reads `/proc/<pid>/exe` to list running apps. Tighten the capability set only if you re-test those features.
- `networking.firewall.checkReversePath` is set to `"loose"` **system-wide** (not scoped to the tunnel) — required for the asymmetric routing TUN mode produces.
- The unit keeps the vendor's `ProtectSystem=false` / `ProtectHome=false` / `PrivateTmp=false`; state lives in `/var/lib/sota-connect` (`StateDirectory`) with a legacy path under `/root/.config/sota-connect` kept writable. Re-hardening these without re-testing may break TUN or the config migration.
- This module merely fetches the client from the vendor's public download link and repackages it; no redistribution restrictions beyond what the vendor already publishes.

## Notes

- Daemon (`sotad`) and sing-box ship side-by-side and must stay in the same directory — the unit runs with `WorkingDirectory` pointed at them.
- The daemon binary is statically linked; the GUI needs the GTK stack, AppIndicator and an at-spi/Tray environment.
- Unofficial community module — not affiliated with Interhive.
