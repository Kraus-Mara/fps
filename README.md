# fps

Search for a movie from the terminal, pick a video source and subtitles, then play it in `mpv`.

## Usage

With [Nix](https://nixos.org/) (flakes enabled):

```sh
nix run github:Kraus-Mara/fps
```

Or from a local clone of the repository:

```sh
nix run .
```

## Without Nix

Dependencies: `bash`, `curl`, `jq`, `fzf`, `mpv`, `kitty` (for `kitten icat`), GNU `grep`, `sed` and `awk`, and Python with `playwright`.

```sh
pip install playwright
playwright install chromium
./fps.sh
```

## Development

```sh
nix develop
./fps.sh
```
