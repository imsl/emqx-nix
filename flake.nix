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

      };

  };
}
