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

        # Build the PBNJ application using Nix's buildNpmPackage
        # This provides full isolation and reproducibility
        pbnj = pkgs.buildNpmPackage {
          pname = "pbnj";
          version = "1.0.0";

          src = ./.;

          # To update this hash:
          # 1. Change it to: npmDepsHash = pkgs.lib.fakeHash;
          # 2. Run: nix build
          # 3. Copy the correct hash from the error message
          npmDepsHash = pkgs.lib.fakeHash;

          # Node.js version
          nodejs = nodejs;

          # Build dependencies for native modules (better-sqlite3)
          nativeBuildInputs = with pkgs; [
            python3
            pkg-config
          ];

          buildInputs = with pkgs; [
            sqlite
          ];

          # Build the Astro application
          buildPhase = ''
            runHook preBuild
            npm run build
            runHook postBuild
          '';

          # Install the built application
          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/pbnj
            cp -r dist $out/lib/pbnj/
            cp -r node_modules $out/lib/pbnj/
            cp -r schema $out/lib/pbnj/
            cp -r scripts $out/lib/pbnj/
            cp package.json $out/lib/pbnj/

            # Create wrapper script
            mkdir -p $out/bin
            cat > $out/bin/pbnj <<EOF
            #!${pkgs.bashInteractive}/bin/bash
            cd $out/lib/pbnj
            exec ${nodejs}/bin/node scripts/init-db.mjs && exec ${nodejs}/bin/node dist/server/entry.mjs "\$@"
            EOF
            chmod +x $out/bin/pbnj

            # Create a simple start script
            cat > $out/bin/pbnj-server <<EOF
            #!${pkgs.bashInteractive}/bin/bash
            cd $out/lib/pbnj
            ${nodejs}/bin/node scripts/init-db.mjs
            exec ${nodejs}/bin/node dist/server/entry.mjs "\$@"
            EOF
            chmod +x $out/bin/pbnj-server

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "A self-hosted pastebin with memorable URLs";
            homepage = "https://github.com/longregen/pbnj";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        # Container image with the fully built application
        containerImage = pkgs.dockerTools.buildLayeredImage {
          name = "pbnj";
          tag = "latest";

          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.cacert
            nodejs
            pbnj
          ];

          config = {
            Env = [
              "NODE_ENV=production"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin:${pkgs.coreutils}/bin:${nodejs}/bin:${pbnj}/bin"
              "HOME=/root"
              "HOST=0.0.0.0"
              "PORT=4321"
              "DATABASE_PATH=/data/pbnj.db"
            ];
            WorkingDir = "${pbnj}/lib/pbnj";
            ExposedPorts = {
              "4321/tcp" = {};
            };
            Volumes = {
              "/data" = {};
            };
            Entrypoint = [ "${pbnj}/bin/pbnj-server" ];
          };

          extraCommands = ''
            mkdir -p tmp data
            chmod 1777 tmp
            chmod 777 data
          '';
        };

      in
      {
        packages = {
          default = pbnj;
          pbnj = pbnj;
          container = containerImage;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
            pkgs.python3
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
          ];

          shellHook = ''
            echo "PBNJ Development Environment"
            echo "Node.js: $(node --version)"
            echo "npm: $(npm --version)"
            echo ""
            echo "Development:"
            echo "  npm install && npm run dev     - Start dev server"
            echo ""
            echo "Nix build:"
            echo "  nix build                      - Build application"
            echo "  nix build .#container          - Build container image"
            echo ""
            echo "Run container:"
            echo "  docker load < result"
            echo "  docker run -e AUTH_KEY=secret -p 4321:4321 -v pbnj-data:/data pbnj"
          '';
        };

        devShells.ci = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.sqlite
            pkgs.git
            pkgs.cacert
            pkgs.python3
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
          ];
        };
      }
    );
}
