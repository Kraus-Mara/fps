{
  description = "Streaming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Environnement Python avec playwright
        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            playwright
          ]
        );
      in
      {
        # Environnement de développement
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            mpv
            yt-dlp
            curl
            pythonEnv
            chromium
          ];

          shellHook = ''
            echo "Type this command to install the necessary Playwright browsers."
            echo "playwright install chromium"
            echo "For nixOS users, get out of the Environnement and run the following command:"
            echo "nix develop --command bash -c 'PLAYWRIGHT_BROWSERS_PATH=$PWD/.browsers playwright install chromium'"
            # Installer les browsers playwright si nécessaire
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
          '';
        };
      }
    );
}
