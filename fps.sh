#!/bin/sh

version="2.0.0"

# =========== fonctions ==========

search_movie() {
  # should ask : search query
  read -p "RECHERCHE : " query
  # spaces in query to %20
  query=$(echo "$query" | sed 's/ /%20/g')
  # then curl by replacing the query in the url 
  response=$(curl -s --request GET \
     --url "https://api.themoviedb.org/3/search/movie?query=${query}&include_adult=false&language=fr-FR&page=1" \
     --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyZGQ1MWNkYTQ4N2UyZWUxMmY1NTkyOTNjYjRlNDI3OCIsIm5iZiI6MTc2NzA0MjQ1NC44NjYsInN1YiI6IjY5NTJlZDk2OWIyNzYzMTQxMmNiZDY0MCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xTWNJtZnSEOkejDg7hwPVkagDs8rbwMuADDta212X5s' \
     --header 'accept: application/json')
  # debug :
  # echo "$response"

  results=$(echo "$response" | jq -rc '.results[]')
  movie_list=$(echo "$results" | while IFS= read -r movie; do
    title=$(echo "$movie" | jq -r '.original_title')
    if [[ -z "$title" ]]; then title="?"; fi
    release_date=$(echo "$movie" | jq -r '.release_date')
    if [[ -z "$release_date" ]]; then release_date="?"; fi
    movie_id=$(echo "$movie" | jq -r '.id')
    if [[ -z "$movie_id" ]]; then movie_id="?"; fi
    l_path=$(echo "$movie" | jq -r '.poster_path')
    if [[ "$l_path" == "null" ]]; then l_path="?"; fi
    echo "$title | $release_date | ID: $movie_id | l_path: $l_path"
  done)

  icat="kitten icat --transfer-mode=memory --stdin=no"
  selected_movie=$(echo "$movie_list" | fzf --height 90% --reverse --border --preview-window=right,33% --preview="$icat https://image.tmdb.org/t/p/w500{-1}")
  movie_id=$(echo "$selected_movie" | sed 's/.*ID: \([0-9]*\)/\1/')
  echo "ID: $movie_id"
}

scrap() {
  response="$(printf "$(python id_to_urls.py $movieID)")"
  declare -A seen
  for line in $response; do
    service=$(echo "$line" | grep -oP "&service=\K[^&]+")
    secret=$(echo "$line" | grep -oP "&secretKey=\K[^&]+")
    key="${service}_${secret}"
    if [[ -z "$service" || -z "$secret" || ${seen[$key]} ]]; then
      continue
    fi
    seen[$key]=1
    echo "=================="
    echo "Secret:$secret"
    echo "Service:$service"
  done
}

fetch_all() {
  rivestream_api="https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=$movieID&service=flowcast&secretKey=$secretKey&proxyMode=undefined"
  response="$(curl -s "$rivestream_api")"
  all_url=$(echo "$response" | jq -r '.data.sources | .[].url')
  all_subs_urls=$(echo "$response" | jq -r '.data.captions | .[].file')
  echo "all urls: $all_url"
  echo "all subs: $all_subs_urls"
}

fetch() {
  rivestream_api="https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=$movieID&service=flowcast&secretKey=$secretKey&proxyMode=undefined"
  response="$(curl -s "$rivestream_api")"
  best_url=$(echo "$response" | jq -r '.data.sources | max_by(.quality) | .url')
  fr_subs_url=$(echo "$response" | jq -r '.data.captions[] | select(.label | contains("Français")) | .file')
  echo "video:$best_url sub:$fr_subs_url"
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
  mpv --referrer="$rivestream_refr" $video --sub-file="$caption_file"
}

# =========== variables ==========

caption_file="french_subtitles.srt"
rivestream_refr="https://www.rivestream.app/"

# =========== main ==========
# search_movie

movieID=$(search_movie | grep -oP "ID: \K[0-9]+")

results=$(scrap)
service=$(echo "$results" | grep -oP "Service:\K[^ ]+")
secretKey=$(echo "$results" | grep -oP "Secret:\K[^ ]+")

echo "Service: $service, Clé: $secretKey"

fetch_res=$(fetch)
video=$(echo "$fetch_res" | grep -oP "video:\K[^ ]+")
subtitles_url=$(echo "$fetch_res" | grep -oP "sub:\K[^ ]+")

echo "Read: $video with sub: $subtitles_url"
download_captions

play

clear

