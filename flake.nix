{
  description = "kowo.dev";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "kowo-website";
            version = "0.0.1";
            src = ./.;

            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.pnpm.configHook
            ];

            pnpmDeps = pkgs.pnpm.fetchDeps {
              pname = "kowo-website";
              version = "0.0.1";
              src = ./.;
              fetcherVersion = 2;
              hash = "sha256-Lyk88cIAhw/22sRvG/LLFCx/wxdzr/Gk6JhetxY0mhE=";
            };

            env.ASTRO_TELEMETRY_DISABLED = 1;

            buildPhase = ''
              pnpm run build
            '';

            installPhase = ''
              mkdir -p $out
              cp -r dist/* $out/
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.nodejs
              pkgs.pnpm
            ];
          };
        }
      );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.services.kowo;
        in
        {
          options.services.kowo = {
            enable = mkEnableOption "kowo.dev";

            domain = mkOption {
              type = types.str;
              default = "kowo.dev";
              description = "Domain name for the website";
            };
          };

          config = mkIf cfg.enable {
            services.caddy = {
              enable = true;
              virtualHosts.${cfg.domain} = {
                serverAliases = [ "www.${cfg.domain}" ];
                extraConfig = ''
                  root * ${self.packages.${pkgs.stdenv.hostPlatform.system}.default}
                  file_server
                  encode gzip
                '';
              };
            };
          };
        };
    };
}
