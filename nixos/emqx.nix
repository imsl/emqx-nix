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

      nodeName = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          The name of the EMQX node. Notice, this name is used for setting up
          the EMQX database. If you change the node name, you need to purge
	  `${cfg.stateDir}/data/mnesia` before starting the service with the
          new name. See the EMQX
          [documentation](https://www.emqx.io/docs/en/v5.0/deploy/install.html#package-installation-linux).
        '';
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/emqx";
        description = lib.mdDoc ''
          State and configuration directory EMQX will use.
        '';
      };

      logDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/emqx";
        description = lib.mdDoc ''
          Log directory EMQX will use.
        '';
      };

      logConsoleHandler = {
        enable = lib.mkEnableOption (lib.mdDoc "console logging");
        level = lib.mkOption {
          type = lib.types.enum [
            "debug" "info" "notice" "warning" "error" "critical" "alert"
            "emergency"
          ];
          default = "warning";
          description = lib.mdDoc ''
            The log level used for EMQX console logs
          '';
        };
      };

    };

  };

  config = lib.mkIf cfg.enable {

    services.emqx.logConsoleHandler.enable = lib.mkDefault true;

    systemd.services.emqx = {
      description = "emqx daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = with pkgs; [
        bash gawk inetutils rsync
      ];
      environment = {
        EMQX_NODE_NAME = cfg.nodeName;
        EMQX_NODE__DATA_DIR = cfg.stateDir;
        EMQX_LOG__CONSOLE_HANDLER__ENABLE =
          if cfg.logConsoleHandler.enable then "true" else "false";
        EMQX_LOG__CONSOLE_HANDLER__LEVEL = cfg.logConsoleHandler.level;
        # We're using upstream OTP, not the EMQX fork, so we must use mnesia
        # See https://github.com/emqx/emqx/discussions/8592
        EMQX_NODE__DB_BACKEND = "mnesia";
      };
      preStart = ''
        # We need to copy the entire emqx package into the state dir because
        # EMQX expects some files to be writeable
        rsync -r --del --chmod=ug+w \
          "${cfg.package}/dist/" "${cfg.stateDir}/dist/"
        echo 'RUNNER_LOG_DIR="${cfg.logDir}"' >> \
          "${cfg.stateDir}/dist/emqx/rel/emqx/releases/emqx_vars"
      '';
      serviceConfig = {
        ExecStart = "${cfg.stateDir}/dist/emqx/rel/emqx/bin/emqx foreground";
        LimitNOFILE = 1048576;
        TimeoutStopSec = "120s";
        Restart = "on-failure";
        RestartSec = "120s";
        StateDirectory =
          lib.mkIf (cfg.stateDir == "/var/lib/emqx") "emqx";
        LogsDirectory =
          lib.mkIf (cfg.logDir == "/var/log/emqx") "emqx";
        DynamicUser = true;
        User = "emqx";
        Group = "emqx";
      };
    };

  };

}
