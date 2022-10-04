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

        emqx = callPackage ./nixpkgs/emqx {};

        emqxTest = testers.nixosTest {
          name = "emqx";
          nodes = {

            server = { config, lib, pkgs, ... }: {

              imports = [ ./nixos/emqx.nix ];

              networking.firewall.allowedTCPPorts = [ 1883 ];

              services.emqx = {
                enable = true;
                package = emqx;
                nodeName = "emqx@127.0.0.1";
                logConsoleHandler.level = "notice";
              };

            };

            client = { pkgs, ... }: {

              environment.systemPackages = with pkgs; [ mosquitto ];

            };

          };

          testScript = ''
            start_all()
            server.wait_for_unit("emqx.service")

            # Verify the MQTT listener comes up
            server.wait_for_open_port(1883)

            # Verify the EMQX web UI listener comes up
            server.wait_for_open_port(18083)

            # Send a retained message to the EMQX broker
            client.succeed("mosquitto_pub -h server -r -t test -m test")

            # Receive the same message in a separate session
            client.succeed("mosquitto_sub -h server -W 5 -C 1 -t test")
          '';
        };

      };

  };
}
