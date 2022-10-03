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

              services.emqx = {
                enable = true;
                package = emqx;
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
