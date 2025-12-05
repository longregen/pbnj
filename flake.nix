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

        # Container image for CI/CD and deployment
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
          ];

          config = {
            Env = [
              "NODE_ENV=production"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${nodejs}/bin"
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
          default = containerImage;
          container = containerImage;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.git
          ];

          shellHook = ''
            echo "PBNJ Development Environment"
            echo "Node.js: $(node --version)"
            echo "npm: $(npm --version)"
            echo ""
            echo "Available commands:"
            echo "  npm install    - Install dependencies"
            echo "  npm run dev    - Start development server"
            echo "  npm run build  - Build for production"
            echo "  npm run deploy - Deploy to Cloudflare Workers"
          '';
        };

        # Minimal CI shell
        devShells.ci = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.git
            pkgs.cacert
          ];
        };
      }
    );
}
