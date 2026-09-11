# sotavpn

[English](README.md) | Русский

> Запуск VPN-клиента [Sota Connect](https://sotavpn.net/) на NixOS — с нормальной упаковкой, рабочим демоном `sotad` и firewall, готовым к TUN.

![License: Freeware](https://img.shields.io/badge/license-Freeware-blue.svg) ![Platform](https://img.shields.io/badge/platform-x86--64--linux-success)

Sota Connect распространяется в виде готового Arch-пакета (`.pkg.tar.zst`), который рассчитывает на обычную FHS-раскладку — `/usr/bin`, `/usr/libexec`, `/usr/lib`. Ничего из этого на NixOS нет. Этот модуль переупаковывает его для Nix store через `autoPatchelf`, поднимает демон `sotad` как укреплённый systemd-сервис и готовит firewall под его TUN-интерфейс.

## Возможности

- 📦 **Нативная упаковка под Nix** — `autoPatchelf` + пропатченные RPATH, без FHS-хаков и материализации в `/opt`
- 🛡️ **Демон как сервис** — `sotad` работает как укреплённый root-юнит systemd (TUN, маршруты, caps для разделения трафика по приложениям)
- 🧩 **Flutter-клиент работает из коробки** — встроенные плагины `dlopen` закрываются чисто; инертные `libjvm` NEEDED-записи удалены
- 🔒 **Готовность к TUN-режиму** — модуль `tun` и доверенный firewall-интерфейс для туннеля

## Установка

Подключите модуль и включите сервис: 

```nix
{
  imports = [
    ./sotavpn-module.nix
  ];

  services.sotavpn.enable = true;
}
```

Пересоберите конфигурацию, затем запустите **Sota Connect** из меню приложений (или командой `sotavpn`). Демон `sotad` стартует автоматически в фоне:

```bash
sudo nixos-rebuild switch
```

## Обновление

Tarball скачивается по `-latest`-ссылке, поэтому его `sha256` зафиксирован в `sotavpn.nix`. Когда выходит новая версия, обновите хеш:

```bash
nix hash file --type sha256 <(curl -sL https://storage.sota.ac/api/v1/public/storage/sotavpn-latest-x64.pkg.tar.zst)
```

Или просто пересоберите — сообщение об ошибке подскажет новый хеш:

```bash
sudo nixos-rebuild switch
```

## Опции

| Опция | По умолчанию | Описание |
| --- | --- | --- |
| `services.sotavpn.enable` | `false` | Включить клиент sotavpn и фоновый демон `sotad`. Модуль фичи в этом репозитории включает опцию при импорте. |
| `services.sotavpn.package` | собирается из `sotavpn.nix` | Переопределить пакет Sota Connect. |
| `services.sotavpn.tunInterface` | `"tun0"` | TUN-устройство, которому доверяет firewall (уже занято `services.happ` — смените, если используете оба). |

## Фикс `libjvm`

Встроенный JNI-клей Flutter (`libdartjni.so`, `libgtk_plugin.so`) несёт ссылку `DT_NEEDED libjvm.so`. При этом `native_assets.json` и `NativeAssetsManifest.json` в комплекте **пустые** — Java native-ассетов в рантайме нет, и в дистрибутиве-цели (Arch) JVM тоже нет. Деривация удаляет NEEDED-запись `libjvm`, чтобы плагины загружались чисто и не тянули за собой JRE на ~300 МБ:

```bash
patchelf --remove-needed libjvm.so "$so"
```

## Компромиссы безопасности

- `sotad` работает **от root с `NoNewPrivileges=true`** и только с `CAP_NET_ADMIN CAP_NET_RAW CAP_DAC_READ_SEARCH CAP_SYS_PTRACE` — он поднимает TUN-интерфейс, настраивает маршруты, читает заголовки пакетов (определение активного окна для разделения трафика) и читает `/proc/<pid>/exe`, чтобы перечислять запущенные приложения. Ужесточайте caps только после повторного тестирования этих функций.
- `networking.firewall.checkReversePath` установлен в `"loose"` **на уровне всей системы** (не только для туннеля) — это требуется из-за асимметричной маршрутизации, которую создаёт TUN-режим.
- Юнит сохраняет вендорские `ProtectSystem=false` / `ProtectHome=false` / `PrivateTmp=false`; состояние живёт в `/var/lib/sota-connect` (`StateDirectory`), а легаси-путь `/root/.config/sota-connect` оставлен доступным для записи. Повторное ужесточение без тестирования может сломать TUN или миграцию конфига.
- Этот модуль лишь скачивает клиент по публичной ссылке вендора и переупаковывает его; никаких ограничений на распространение сверх тех, что вендор уже публикует, нет.

## Примечания

- Демон (`sotad`) и sing-box поставляются рядом и должны оставаться в одной директории — юнит запускается с `WorkingDirectory`, указывающим на них.
- Бинарник демона статически слинкован; GUI требует GTK-стек, AppIndicator и окружение at-spi/Tray.
- Неофициальный модуль сообщества — не аффилирован с Interhive.
