{
  description = "Packaging EMQX";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.05";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux =

      let

        inherit (nixpkgs.legacyPackages.x86_64-linux)
          rebar3 fetchFromGitHub;

      in {

        inherit rebar3;

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

      };

  };
}
