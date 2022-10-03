{ config, lib, pkgs, ... }:

let

  cfg = config.services.emqx;

in {

  options = {

    services.emqx = {

      enable = lib.mkEnableOption (lib.mdDoc "EMQX MQTT broker");

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.emqx;
        description = lib.mdDoc ''
          The EMQX package the service should use.
        '';
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/emqx";
        description = lib.mdDoc ''
          State and configuration directory EMQX will use.
        '';
      };

    };

  };

  config = lib.mkIf cfg.enable {

    systemd.services.emqx = {
      description = "emqx daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = with pkgs; [
        bash gawk inetutils
      ];
      environment = {
        EMQX_NODE__DATA_DIR = cfg.stateDir;
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/emqx foreground";
        LimitNOFILE = 1048576;
        TimeoutStopSec = "120s";
        Restart = "on-failure";
        RestartSec = "120s";

        StateDirectory =
          lib.mkIf (cfg.stateDir == "/var/lib/emqx") "emqx";
      };
    };

  };

}
