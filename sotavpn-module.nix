{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.services.sotavpn;
in
{
  options.services.sotavpn = {
    enable = mkEnableOption "Sota Connect: the sotavpn client and the background sotad daemon";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./sotavpn.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./sotavpn.nix { }";
      description = "The Sota Connect package to use.";
    };

    tunInterface = mkOption {
      type = types.str;
      default = "tun0";
      description = ''
        Name of the TUN interface sotad/sing-box brings up, added to the
        firewall's trusted interfaces so tunnelled traffic is not dropped.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    boot.kernelModules = [ "tun" ];
    networking.firewall.checkReversePath = lib.mkDefault "loose";
    networking.firewall.trustedInterfaces = [ cfg.tunInterface ];

    systemd.services.sotad = {
      description = "Sota Connect Daemon (sotad)";
      documentation = [ "https://interhive.org/" ];
      after = [ "network.target" "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      # ExecStart is a Nix store path, so a package bump changes the store
      # path; without restartTriggers systemd would keep running the old
      # binary across rebuilds.
      restartTriggers = [ cfg.package ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/libexec/sota-daemon/sotad";
        WorkingDirectory = "${cfg.package}/libexec/sota-daemon";
        Restart = "on-failure";
        RestartSec = "5s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "sotad";

        # Mirrors the hardening shipped in the vendor's own sotad.service.
        NoNewPrivileges = true;
        PrivateTmp = false;
        ProtectSystem = false;
        ProtectHome = false;
        StateDirectory = "sota-connect";
        StateDirectoryMode = "0750";
        ReadWritePaths = "-/root/.config/sota-connect /tmp /var/lib/sota-connect";

        # TUN interface + routes + packet capture + process introspection.
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_DAC_READ_SEARCH" "CAP_SYS_PTRACE" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_DAC_READ_SEARCH" "CAP_SYS_PTRACE" ];
        LimitNOFILE = 65536;
      };
    };
  };
}