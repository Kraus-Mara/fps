#!/usr/bin/env bash

# =========== fonctions ==========

search_movie() {
  read -p "RECHERCHE : " query
  query=$(echo "$query" | sed 's/ /%20/g')
  response=$(curl -s --request GET \
    --url "https://api.themoviedb.org/3/search/movie?query=${query}&include_adult=false&language=fr-FR&page=1" \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyZGQ1MWNkYTQ4N2UyZWUxMmY1NTkyOTNjYjRlNDI3OCIsIm5iZiI6MTc2NzA0MjQ1NC44NjYsInN1YiI6IjY5NTJlZDk2OWIyNzYzMTQxMmNiZDY0MCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xTWNJtZnSEOkejDg7hwPVkagDs8rbwMuADDta212X5s' \
    --header 'accept: application/json')

  results=$(echo "$response" | jq -rc '.results[]')
  movie_list=$(echo "$results" | while IFS= read -r movie; do
    title=$(echo "$movie" | jq -r '.original_title')
    [ -z "$title" ] && title="?"
    release_date=$(echo "$movie" | jq -r '.release_date')
    [ -z "$release_date" ] && release_date="?"
    movie_id=$(echo "$movie" | jq -r '.id')
    [ -z "$movie_id" ] && movie_id="?"
    l_path=$(echo "$movie" | jq -r '.poster_path')
    [ "$l_path" = "null" ] && l_path="?"
    echo "$title | $release_date | ID: $movie_id | l_path: $l_path"
  done)

  icat="kitten icat --transfer-mode=memory --stdin=no"
  selected_movie=$(echo "$movie_list" | fzf --height 90% --reverse --border --preview-window=right,33% --preview="$icat https://image.tmdb.org/t/p/w500{-1}")
  movie_id=$(echo "$selected_movie" | sed 's/.*ID: \([0-9]*\)/\1/')
  echo "ID: $movie_id"
}

scrap() {
  response="$(printf '%s' "$(python "$id_to_urls" "$movieID")")"
  declare -A seen
  for line in $response; do
    service=$(echo "$line" | grep -oP "&service=\K[^&]+")
    secret=$(echo "$line" | grep -oP "&secretKey=\K[^&]+")
    key="${service}_${secret}"
    [ -z "$service" ] || [ -z "$secret" ] || [ -n "${seen[$key]}" ] && continue
    seen[$key]=1
    echo "Service:$service Secret:$secret"
  done
}

draw_bar() {
  local cur=$1 total=$2
  local width=30
  if [ "$total" -le 0 ]; then
    printf '\r\033[K[%s] %3d%% (0/0)' "$(printf '░%.0s' $(seq 1 $width))" 100 >&2
    return
  fi
  local pct=$(( cur * 100 / total ))
  local filled=$(( cur * width / total ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty;  i++)); do bar="${bar}░"; done
  printf '\r\033[K[%s] %3d%% (%d/%d)' "$bar" "$pct" "$cur" "$total" >&2
}

query_video_sources() {
  svc="$1"
  key="$2"
  rivestream_api="https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=$movieID&service=$svc&secretKey=$key&proxyMode=false"
  response="$(curl -s "$rivestream_api")"

  echo "$response" | jq -r '.data.sources[]? | "VIDEO|'"$svc"'|\(.quality)|\(.url)"'
}

collect_videos() {
  total_video=$(printf '%s\n' "$results" | grep -c "Service:")
  n_video=0
  printf '%s\n' "$results" | while IFS= read -r line; do
    svc=$(echo "$line" | grep -oP "Service:\K[^ ]+")
    key=$(echo "$line" | grep -oP "Secret:\K[^ ]+")
    [ -z "$svc" ] && continue

    n_video=$((n_video + 1))
    draw_bar "$n_video" "$total_video"
    query_video_sources "$svc" "$key"
  done
  printf '\r\033[K' >&2
}

query_subtitles() {
  svc="$1"
  key="$2"
  rivestream_api="https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=$movieID&service=$svc&secretKey=$key"
  response="$(curl -s "$rivestream_api")"

  echo "$response" | jq -r '.data.captions[]? | "SUB|'"$svc"'|\(.label)|\(.file)"'
}

collect_subtitles() {
  total_sub=$(printf '%s\n' "$results" | grep -c "Service:")
  n_sub=0
  printf '%s\n' "$results" | while IFS= read -r line; do
    svc=$(echo "$line" | grep -oP "Service:\K[^ ]+")
    key=$(echo "$line" | grep -oP "Secret:\K[^ ]+")
    [ -z "$svc" ] && continue

    n_sub=$((n_sub + 1))
    draw_bar "$n_sub" "$total_sub"
    query_subtitles "$svc" "$key"
  done
  printf '\r\033[K' >&2
}

download_captions() {
  if [ -n "$subtitles_url" ]; then
    echo "Downloading subtitles..."
    curl "$subtitles_url" --output "$caption_file"
  else
    echo "No subtitles found to download."
  fi
}

play() {
  mpv --referrer="$rivestream_refr" "$video" --sub-files="$caption_file"
}

# =========== variables ==========

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/fps.XXXXXX") || exit 1
trap 'rm -rf "$tmpdir"' EXIT INT TERM

caption_file="$tmpdir/subtitles.srt"
rivestream_refr="https://www.rivestream.app/"
id_to_urls="${FPS_ID_TO_URLS:-$(dirname "$0")/id_to_urls.py}"

# =========== main ==========

movieID=$(search_movie | grep -oP "ID: \K[0-9]+")
results=$(scrap)
echo "$results"

all_videos=$(collect_videos)
echo "$all_videos"
if [ -z "$all_videos" ]; then
  echo "Aucune source vidéo trouvée."
  exit 1
fi

video_list=$(echo "$all_videos" | awk -F'|' '{print $2" - "$3"|"$4}')
selected_video=$(echo "$video_list" | fzf --height 50% --reverse --prompt="Video source> " -d'|' --with-nth=1)
video=$(echo "$selected_video" | cut -d'|' -f2)

if [ -z "$video" ]; then
  echo "Aucune vidéo sélectionnée."
  exit 1
fi

all_subs=$(collect_subtitles)

if [ -z "$all_subs" ]; then
  echo "Aucun sous-titre trouvé"
  subtitles_url=""
else
  sub_list=$(echo "$all_subs" | awk -F'|' '{print $2" - "$3"|"$4}')
  selected=$(echo "$sub_list" | fzf --height 50% --reverse --prompt="Subtitles> " -d'|' --with-nth=1)
  subtitles_url=$(echo "$selected" | cut -d'|' -f2)
fi

echo "Read:$video with sub:$subtitles_url"
download_captions

play

# clear
