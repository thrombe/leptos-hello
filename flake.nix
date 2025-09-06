{
  description = "yaaaaaaaaaaaaaaaaaaaaa";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    candid-extractor = {
      url = "github:dfinity/candid-extractor";
      flake = false;
    };
    generate-did = {
      url = "github:Stephen-Kimoi/generate-did";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-darwin"] (system: let
      config = {
        allowUnfree = true;
      };

      overlays = [
        (self: super: {})
      ];
      pkgs = import inputs.nixpkgs {
        inherit system config overlays;
      };

      dfxvm = let
        platformMap = {
          x86_64-linux = {
            arch = "x86_64-unknown-linux-gnu";
            sha256 = "sha256-6vJ4HNTMTSgOaDjfQ5TPmdFdtUPN65h8K6ie06koqQM=";
          };
          aarch64-darwin = {
            arch = "aarch64-apple-darwin";

            # TODO: update this with real hash (i don't have a mac)
            sha256 = pkgs.lib.fakeSha256;
          };
        };

        platform = platformMap.${system} or (throw "Unsupported platform for dfxvm: ${system}");
      in
        pkgs.stdenv.mkDerivation {
          pname = "dfxvm";
          version = "latest";

          src = pkgs.fetchurl {
            url = "https://github.com/dfinity/dfxvm/releases/latest/download/dfxvm-${platform.arch}.tar.gz";
            sha256 = platform.sha256;
          };

          unpackPhase = ''
            tar -xzf $src --strip-components=1
          '';

          installPhase = ''
            mkdir -p $out/bin
            chmod +x dfxvm
            mv dfxvm $out/bin/dfxvm
          '';
        };
      dfx = let
        version = "0.29.0";

        platformMap = {
          x86_64-linux = {
            arch = "x86_64-unknown-linux-gnu";
            sha256 = "sha256-3//iVYyAVPeO681Vx8nFlNdO6MTQ91qcSiwbjXWVeHU=";
          };
          aarch64-darwin = {
            arch = "aarch64-apple-darwin";

            # TODO: update this with real hash (i don't have a mac)
            sha256 = pkgs.lib.fakeSha256;
          };
        };

        platform = platformMap.${system} or (throw "Unsupported platform for dfx ${version}: ${system}");
      in
        pkgs.stdenv.mkDerivation {
          pname = "dfx";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/dfinity/sdk/releases/download/${version}/dfx-${platform.arch}.tar.gz";
            sha256 = platform.sha256;
          };

          unpackPhase = ''
            tar -xzf $src --strip-components=1
          '';

          installPhase = ''
            mkdir -p $out/bin
            install -m755 dfx $out/bin/
          '';
        };

      candid-extractor = pkgs.rustPlatform.buildRustPackage {
        pname = "candid-extractor";
        version = (pkgs.lib.importTOML "${inputs.candid-extractor}/Cargo.toml").package.version;
        src = inputs.candid-extractor;
        cargoLock.lockFile = "${inputs.candid-extractor}/Cargo.lock";
      };

      generate-did = pkgs.rustPlatform.buildRustPackage {
        pname = "generate-did";
        version = (pkgs.lib.importTOML "${inputs.generate-did}/Cargo.toml").package.version;
        src = inputs.generate-did;
        cargoLock.lockFile = "${inputs.generate-did}/Cargo.lock";
        doCheck = false;
      };

      fhs = pkgs.buildFHSEnv {
        name = "fhs-shell";
        targetPkgs = p: (packages p) ++ (custom-commands p) ++ [];
        runScript = "${pkgs.zsh}/bin/zsh";
        profile = ''
          export FHS=1
          source ./.env
        '';
      };
      custom-commands = pkgs: [];

      packages = pkgs:
        (with pkgs; [
          # rustup
          trunk
          cargo-binstall
          cargo
          rustc
          rust-analyzer
          rustfmt
          nodejs
          lld

          typescript-language-server
        ])
        ++ [
          dfxvm
          dfx
          candid-extractor
          generate-did
        ];

      stdenv =
        if pkgs.stdenv.isDarwin
        then pkgs.darwin.apple_sdk.frameworks.Security
        else pkgs.clangStdenv;
    in {
      devShells.default =
        pkgs.mkShell.override {
          inherit stdenv;
        } {
          nativeBuildInputs = [fhs] ++ packages pkgs ++ custom-commands pkgs;
          shellHook = ''
              ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              export SECURITY_FRAMEWORK_PATH="${pkgs.darwin.apple_sdk.frameworks.Security}"
              export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            ''}

            source ./.env
          '';
        };
    });
}
