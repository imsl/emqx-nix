{ fetchHex, rebar3Relx, buildRebar3, fetchRebar3Deps
, rebar3-proper, pc, erlfmt, hex
, fetchFromGitHub, fetchgit, fetchurl, stdenv, lib, writeScript, gitMinimal
, curl, unzip, cmake, cacert, erlang
}:

let

  version = "5.0.7";
  owner = "emqx";
  repo = "emqx";

  src = fetchFromGitHub {
    inherit owner repo;
    sha256 = "sha256-Lga+TRxU58zi3nuYsil5rPn6wptkWjLcN7m2bAXQZBA=";
    rev = "v${version}";
  };

  dashboardRepo = "emqx-dashboard-web-new";
  dashboardVersion = "v1.0.8";
  dashboardFile = "emqx-dashboard.zip";
  dashboard = fetchurl {
    url = "https://github.com/emqx/${dashboardRepo}/releases/download/${dashboardVersion}/${dashboardFile}";
    sha256 = "sha256-931nUMAjPgiTNoOws2tmDtKaJWAPgkBatnnn2d/xzMY=";
  };

  deps = (fetchRebar3Deps rec {
    name = "emqx";
    inherit version src;
    sha256 = "sha256-n2f27bwQrYPvE49noEDFlt5coRZHoZgOSX8GCmaKBPE=";
  }).overrideAttrs (_: _: {
    buildInputs = [ gitMinimal ];
    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    postInstall = ''
      find "$out" -type d -name .git | xargs -t rm -rf
    '';
  });

  rebar3-gpb = buildRebar3 rec {
    name = "rebar3_gpb_plugin";
    # Versions > 2.19.1 give build errors, see
    # https://github.com/lrascao/rebar3_gpb_plugin/issues/147
    version = "2.19.1";
    src = fetchHex {
      pkg = name;
      inherit version;
      sha256 = "sha256-t6mu2GHGAbpcyOGyF8MA5C1T6L0J3Jo7aRGdl84s0Do=";
    };
    beamDeps = [ gpb ];
  };

  getopt = buildRebar3 {
    name = "getopt";
    version = "1.0.1";
    src = fetchHex {
      pkg = "getopt";
      version = "1.0.1";
      sha256 = "sha256-U+Grg7nOtlyWctPno1uAkum9ybPugHIUcaFhwQxZlZw=";
    };
    beamDeps = [ ];
  };

  providers = buildRebar3 {
    name = "providers";
    version = "1.8.1";
    src = fetchHex {
      pkg = "providers";
      version = "1.8.1";
      sha256 = "sha256-5FdFrenEdqmkaeoIQOQYqxk2DcRPAaIzME4RikRIa6A=";
    };
    beamDeps = [ getopt ];
  };

  provider_asn1 = buildRebar3 rec {
    name = "provider_asn1";
    version = "0.3.0";
    src = fetchHex {
      pkg = name;
      inherit version;
      sha256 = "sha256-MuelWYZi01rBut8jM6a5alMZizPGZoBE/LveSRu/+wU=";
    };
    beamDeps = [ providers ];
  };

  gpb = buildRebar3 rec {
    name = "gpb";
    version = "4.19.5";
    src = fetchHex {
      pkg = name;
      version = version;
      sha256 = "sha256-IbdnUNZrRZzkDLFCmPs4744BYdm2cqUoRYXAJWOAb44=";
    };
    beamDeps = [ ];
    postPatch = ''
      echo "${version}" > gpb.vsn
      patchShebangs build/*
    '';
    buildPhase = ''
      HOME=. DEBUG=1 DIAGNOSTIC=1 make
    '';
  };

  rebar3-grpc = buildRebar3 rec {
    name = "rebar3_grpc_plugin";
    version = "0.10.2";
    src = fetchFromGitHub {
      owner = "HJianBo";
      repo = "grpc_plugin";
      rev = "v${version}";
      sha256 = "sha256-fXi01h+Vsl6h8O+hfJlBDZ7U4Qfn+kBnfnDG9e/VeAw=";
    };
    beamDeps = [ gpb providers ];
  };

  verl = buildRebar3 {
    name = "verl";
    version = "1.1.1";
    src = fetchHex {
      pkg = "verl";
      version = "1.1.1";
      sha256 = "sha256-CSXlHNkqCovicXZbAkMLLiz/isMO8k0SO9DVhRHo+xg=";
    };
    beamDeps = [ ];
  };

  hex_core = buildRebar3 {
    name = "hex_core";
    version = "0.8.4";
    src = fetchHex {
      pkg = "hex_core";
      version = "0.8.4";
      sha256 = "sha256-S4wh+gSVFdd4OV44sNDl1It+zccDu6H3AH4mUSks5ho=";
    };
    beamDeps = [ ];
  };

  rebar3-hex = buildRebar3 {
    name = "rebar3_hex";
    version = "7.0.2";
    src = fetchHex {
      pkg = "rebar3_hex";
      version = "7.0.2";
      sha256 = "sha256-5TeUXyQy73rnOxDM+5Ef8uhAcd6/LA4/cii+WMhprd4=";
    };
    beamDeps = [ hex_core verl ];
  };

in rebar3Relx {
  pname = "emqx";
  inherit version;

  passthru.deps = deps;
  passthru.gpb = gpb;

  src = fetchFromGitHub {
    inherit owner repo;
    sha256 = "sha256-Lga+TRxU58zi3nuYsil5rPn6wptkWjLcN7m2bAXQZBA=";
    rev = "v${version}";
  };

  checkouts = deps;

  releaseType = "release";

  postConfigure = ''
    patchShebangs \
      scripts/find-apps.sh \
      scripts/find-props.sh \
      scripts/find-suites.sh \
      scripts/git-hooks-init.sh \
      scripts/get-elixir-vsn.sh \
      scripts/get-otp-vsn.sh \
      scripts/prepare-build-deps.sh \
      build \
      pkg-vsn.sh \
      scripts/pre-compile.sh \
      scripts/get-dashboard.sh \
      scripts/merge-config.escript \
      scripts/merge-i18n.escript \

    ln -svf "${writeScript "get-distro.sh" ''
      #!/bin/sh
      echo nixos22.05
    ''}" scripts/get-distro.sh

    ln -svf "$(type -P rebar3)" rebar3

    substituteInPlace Makefile \
      --replace \
        '$(REBAR): prepare ensure-rebar3' \
        '$(REBAR): prepare'

    substituteInPlace pkg-vsn.sh \
      --replace \
        'tag="$(git describe --tags --match "''${GIT_TAG_PREFIX}*" --exact 2>/dev/null)"' \
        'tag="v${version}"'

    substituteInPlace scripts/get-dashboard.sh \
      --replace \
        'DIRECT_DOWNLOAD_URL="https://github.com/emqx/''${DASHBOARD_REPO}/releases/download/''${VERSION}/''${RELEASE_ASSET_FILE}"' \
        'DIRECT_DOWNLOAD_URL="file://${dashboard}"'

    cp --no-preserve=all -vf \
      "${erlang}/lib/erlang/lib/eldap-1.2.9/ebin/ELDAPv3.hrl" \
      "_checkouts/eldap2/include/ELDAPv3.hrl"

    # Avoids running git and failing the build because missing .git directory
    find _checkouts/emqtt -type f | \
      xargs -t sed -i 's/git describe --tags --always/echo 0000000/g'

    # Create subdirectory that the build script expects to exist
    mkdir _checkouts/gpb/ebin
  '';

  BUILD_WITHOUT_QUIC = "1";
  BUILD_WITHOUT_JQ = "1";
  BUILD_WITHOUT_ROCKSDB = "1"; # Temporarily disabled

  buildPlugins = [
    pc
    rebar3-proper
    rebar3-gpb
    rebar3-grpc
    rebar3-hex
    gpb
    provider_asn1
  ];

  buildInputs = [
    cmake
    curl
    gitMinimal
    unzip
  ];

  buildPhase = ''
    HOME=. DEBUG=1 DIAGNOSTIC=1 make
  '';

  dontRewriteSymlinks = true;

  installPhase = ''
    mkdir -p $out/bin
    mv _build $out/
    ln -svt $out/bin $out/_build/emqx/rel/emqx/bin/emqx
  '';
}
