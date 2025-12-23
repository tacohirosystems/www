{
  description = "An empty flake template that you can adapt to your own environment";

  # Flake inputs
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  # Flake outputs
  outputs =
    { self, ... }@inputs:
    let
      # The systems supported for this flake's outputs
      supportedSystems = [
        "x86_64-linux"
      ];

      # Helper for providing system-specific attributes
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            # Provides a system-specific, configured Nixpkgs
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Enable using unfree packages
              config.allowUnfree = true;
            };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShellNoCC {
            # The Nix packages provided in the environment
            packages = with pkgs; [
              self.formatter.${system}
              nil
              nixpkgs-fmt
              caddy
            ];

            env = { };
            shellHook = "";
          };
        }
      );

      packages = forEachSupportedSystem (
        { pkgs, system }: {
          www = pkgs.stdenv.mkDerivation {
            version = "0.0.1";
            name = "www";
            src = ./.;
            buildInputs = [];
            nativeBuildInputs = with pkgs; [ gzip brotli esbuild minhtml imagemagick ];

            buildPhase = ''
              mkdir -p $out/assets/images
              mkdir -p $out/assets/css

              # Images
              cp -r assets/images $out/assets
              mogrify -quality 8 -strip -resize 25x25 $out/assets/images/ceo.webp

              # HTML
              find . -name '*.html' -execdir minhtml --keep-closing-tags --minify-js --minify-css {} --output {} \;
              find . -name '*.html' -execdir brotli --best {} -f \;
              find . -name '*.html' -execdir gzip --best --keep {} -f \;
              cp *.html* $out

              # CSS
              esbuild ./assets/css/*.css --minify --outdir=$out/assets/css
              find $out/assets/css -name '*.css' -execdir brotli --best {} -f \;
              find $out/assets/css -name '*.css' -execdir gzip --best --keep {} -f \;
            '';
          };
        }
      );

      # Nix formatter

      # This applies the formatter that follows RFC 166, which defines a standard format:
      # https://github.com/NixOS/rfcs/pull/166

      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
