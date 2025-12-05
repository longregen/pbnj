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

        # Runtime container image for PBNJ
        # Usage: Build your app first (npm run build), then run:
        #   nix build .#container
        #   docker load < result
        #   docker run -v $(pwd)/dist:/app/dist -v $(pwd)/node_modules:/app/node_modules \
        #              -v $(pwd)/schema:/app/schema -v pbnj-data:/data \
        #              -e AUTH_KEY=your-key -p 4321:4321 pbnj:latest
        runtimeImage = pkgs.dockerTools.buildLayeredImage {
          name = "pbnj";
          tag = "latest";

          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.findutils
            pkgs.cacert
            nodejs
            pkgs.sqlite
          ];

          config = {
            Env = [
              "NODE_ENV=production"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${nodejs}/bin:${pkgs.sqlite}/bin"
              "HOME=/root"
              "HOST=0.0.0.0"
              "PORT=4321"
              "DATABASE_PATH=/data/pbnj.db"
            ];
            WorkingDir = "/app";
            ExposedPorts = {
              "4321/tcp" = {};
            };
            Volumes = {
              "/data" = {};
            };
            Entrypoint = [ "${pkgs.bashInteractive}/bin/bash" "-c" ];
            Cmd = [ "node scripts/init-db.mjs && exec node dist/server/entry.mjs" ];
          };

          extraCommands = ''
            mkdir -p app tmp root data
            chmod 1777 tmp
            chmod 777 data
          '';
        };

        # Builder container with all build dependencies
        # Useful for CI environments that need to build native npm modules
        builderImage = pkgs.dockerTools.buildLayeredImage {
          name = "pbnj-builder";
          tag = "latest";

          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
            pkgs.cacert
            pkgs.curl
            pkgs.git
            nodejs
            pkgs.sqlite
            # Build tools for native npm modules
            pkgs.python3
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
          ];

          config = {
            Env = [
              "NODE_ENV=development"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${nodejs}/bin:${pkgs.sqlite}/bin:${pkgs.python3}/bin:${pkgs.gnumake}/bin:${pkgs.gcc}/bin"
              "HOME=/root"
            ];
            WorkingDir = "/app";
            Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
          };

          extraCommands = ''
            mkdir -p app tmp root
            chmod 1777 tmp
          '';
        };

      in
      {
        packages = {
          default = runtimeImage;
          container = runtimeImage;
          builder = builderImage;
        };

        # Development shell with all tools needed for local development
        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
            # Build tools for better-sqlite3
            pkgs.python3
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
          ];

          shellHook = ''
            echo "PBNJ Development Environment"
            echo "Node.js: $(node --version)"
            echo "npm: $(npm --version)"
            echo "SQLite: $(sqlite3 --version)"
            echo ""
            echo "Node.js (standalone) commands:"
            echo "  npm run dev          - Start dev server"
            echo "  npm run build        - Build for production"
            echo "  npm run start        - Run production server"
            echo ""
            echo "Cloudflare commands:"
            echo "  npm run dev:cloudflare   - Start Cloudflare dev server"
            echo "  npm run build:cloudflare - Build for Cloudflare"
            echo "  npm run deploy           - Deploy to Cloudflare"
            echo ""
            echo "Container commands:"
            echo "  nix build .#container    - Build runtime container"
            echo "  nix build .#builder      - Build builder container"
          '';
        };

        # Minimal CI shell for GitHub Actions
        devShells.ci = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
            pkgs.cacert
            # Build tools for better-sqlite3
            pkgs.python3
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
          ];
        };
      }
    );
}
