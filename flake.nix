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

        runtimeDeps = with pkgs; [
          mpv
          curl
          jq
          fzf
          kitty
          pythonEnv
          coreutils
          gnugrep
          gnused
          gawk
        ];

        fps = pkgs.stdenvNoCC.mkDerivation {
          pname = "fps";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            install -Dm755 fps.sh $out/bin/fps
            install -Dm644 id_to_urls.py $out/share/fps/id_to_urls.py

            wrapProgram $out/bin/fps \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
              --set FPS_ID_TO_URLS $out/share/fps/id_to_urls.py \
              --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers} \
              --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true

            runHook postInstall
          '';

          meta = {
            description = "Recherche et lecture de films en streaming depuis le terminal";
            mainProgram = "fps";
          };
        };
      in
      {
        # nix build / nix run
        packages.default = fps;

        apps.default = flake-utils.lib.mkApp { drv = fps; };

        # Environnement de développement
        devShells.default = pkgs.mkShell {
          buildInputs =
            runtimeDeps
            ++ (with pkgs; [
              yt-dlp
              chromium
            ]);

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
