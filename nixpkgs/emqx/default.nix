{ callPackage, fetchFromGitHub, beamPackages, rebar3, rebar3WithPlugins }:

let

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

in beamPackages.callPackage ./emqx.nix {
  rebar3Relx = beamPackages.rebar3Relx.override {
    rebar3WithPlugins = attrs: rebar3WithPlugins (attrs // {
      rebar3 = rebar3-emqx;
    });
  };
  fetchRebar3Deps = beamPackages.fetchRebar3Deps.override {
    rebar3 = rebar3-emqx;
  };
}
