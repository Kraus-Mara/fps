#!/bin/sh

version="1.0.0"

# =========== functions ==========

scrap() {
  response="$(printf "$(python id_to_urls.py $movieID)")"
  for line in $response; do
    if [[ "$line" != http* ]]; then
      echo "no secret key found in '$line'"
    fi
    service=$(echo "$line" | grep -oP "&service=\K[^&]+")
    secret=$(echo "$line" | grep -oP "&secretKey=\K[^&]+")
    echo "Service:$service Secret:$secret"
  done
}

fetch_all() {
  rivestream_api="https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=$movieID&service=flowcast&secretKey=$secretKey&proxyMode=undefined"
  response="$(curl -s "$rivestream_api")"
  all_url=$(echo "$response" | jq -r '.data.sources | .[].url')
  all_subs_urls=$(echo "$response" | jq -r '.data.captions | .[].file')
  # echo "all urls: $all_url"
  # echo "all subs: $all_subs_urls"
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
agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
rivestream_refr="https://www.rivestream.app/"
rivestream_base="rivestream.app/embed?type=movie&id="

# =========== MAIN ==========
if [ $# -eq 0 ]; then
  echo "Usage: $0 <movie id>"
  exit 1
fi
movieID="$1"
results=$(scrap)
service=$(echo "$results" | grep -oP "Service:\K[^ ]+")
secretKey=$(echo "$results" | grep -oP "Secret:\K[^ ]+")

# echo "Using service: $service with secretKey: $secretKey"
# fetch_all

fetch_res=$(fetch)
video=$(echo "$fetch_res" | grep -oP "video:\K[^ ]+")
subtitles_url=$(echo "$fetch_res" | grep -oP "sub:\K[^ ]+")

# echo "Read: $video with sub: $subtitles_url"
download_captions

play
