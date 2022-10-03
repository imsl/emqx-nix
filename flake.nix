{
  description = "Packaging EMQX";

  inputs = {
    nixpkgs.url = "github:imsl/nixpkgs/rebar3-fixes";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux =

      let

        inherit (nixpkgs.legacyPackages.x86_64-linux)
          beamPackages
          cacert
          callPackage
          fetchFromGitHub
          fetchgit
          gitMinimal
          testers
          ;

        inherit (beamPackages)
          rebar3
          rebar3Relx
          rebar3WithPlugins
          fetchRebar3Deps
          ;

      in rec {

        rebar3-with-nix = rebar3WithPlugins {
          globalPlugins = [ beamPackages.rebar3-nix ];
        };

        rebar3-emqx = rebar3.overrideAttrs (_: drv: rec {
          pname = "rebar3";
          version = "3.18.0-emqx-1";

          src = fetchFromGitHub {
            owner = "emqx";
            repo = "rebar3";
            rev = version;
            sha256 = "sha256-QNBPIIoZ3Et1U9Wwwfw9FqbBLdJh96fxU1384Klgevc=";
          };

          postPatch = ''
            ${drv.postPatch or ""}
            substituteInPlace build \
              --replace '$(git describe --tag)' "${version}"
            substituteInPlace src/rebar.app.src.script \
              --replace '{cmd, "git describe --tags"}' '"${version}"'
          '';
        });

        emqx = beamPackages.callPackage ./emqx.nix {
          rebar3Relx = rebar3Relx.override {
            rebar3WithPlugins = attrs: rebar3WithPlugins (attrs // {
              rebar3 = rebar3-emqx;
            });
          };
          fetchRebar3Deps = fetchRebar3Deps.override {
            rebar3 = rebar3-emqx;
          };
        };

        emqxTest = testers.nixosTest {
          name = "emqx";
          nodes = {
            server = { config, lib, pkgs, ... }: let cfg = config.services.emqx; in {

              imports = lib.singleton {
                services.emqx.enable = true;
              };

              options = {

                services.emqx = {

                  enable = lib.mkEnableOption (lib.mdDoc "EMQX MQTT broker");

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
                    ExecStart = "${emqx}/bin/emqx foreground";
                    LimitNOFILE = 1048576;
                    TimeoutStopSec = "120s";
                    Restart = "on-failure";
                    RestartSec = "120s";

                    StateDirectory =
                      lib.mkIf (cfg.stateDir == "/var/lib/emqx") "emqx";
                  };
                };

              };

            };

            #client = { };
          };

          testScript = ''
            start_all()
            server.wait_for_unit("emqx.service")
            server.wait_for_open_port(1883)
          '';
        };

      };

  };
}
