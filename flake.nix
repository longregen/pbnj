{
  description = "PBNJ - A self-hosted pastebin with memorable URLs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        nodejs = pkgs.nodejs_20;

        # Container image for running the PBNJ server
        containerImage = pkgs.dockerTools.buildLayeredImage {
          name = "pbnj";
          tag = "latest";

          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.cacert
            pkgs.curl
            pkgs.git
            nodejs
            # SQLite support
            pkgs.sqlite
          ];

          config = {
            Env = [
              "NODE_ENV=production"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${nodejs}/bin:${pkgs.sqlite}/bin"
              "HOME=/root"
              "DATABASE_PATH=/data/pbnj.db"
            ];
            WorkingDir = "/app";
            ExposedPorts = {
              "4321/tcp" = {};
            };
            Volumes = {
              "/data" = {};
            };
            Cmd = [ "${nodejs}/bin/node" "dist/server/entry.mjs" ];
          };

          extraCommands = ''
            mkdir -p app tmp root data
            chmod 1777 tmp
            chmod 777 data
          '';
        };

      in
      {
        packages = {
          default = containerImage;
          container = containerImage;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
          ];

          shellHook = ''
            echo "PBNJ Development Environment"
            echo "Node.js: $(node --version)"
            echo "npm: $(npm --version)"
            echo "SQLite: $(sqlite3 --version)"
            echo ""
            echo "Available commands:"
            echo "  npm install    - Install dependencies"
            echo "  npm run dev    - Start development server"
            echo "  npm run build  - Build for production"
            echo "  npm run start  - Run production server"
            echo "  npm run db:init - Initialize database"
          '';
        };

        # Minimal CI shell
        devShells.ci = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
            pkgs.cacert
          ];
        };
      }
    );
}
