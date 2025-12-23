import requests
import json
import urllib.parse
from id_to_urls import id_to_urls

MOVIE_ID = 335983


def extract_video_urls():
    # URL de l'API
    movie_id = MOVIE_ID
    # api_url = "https://www.rivestream.app/api/backendfetch?requestID=movieVideoProvider&id=755898&service=flowcast&secretKey=LTU0YWQzNzhk&proxyMode=undefined"
    api_url = id_to_urls(movie_id)[0]

    print(f"Requete API pour movie ID: {movie_id}")
    print(f"URL: {api_url}\n")

    try:
        # Faire la requête
        response = requests.get(api_url)
        response.raise_for_status()

        # Parser le JSON
        data = response.json()

        if "data" in data and "sources" in data["data"]:
            sources = data["data"]["sources"]

            print(f"{'=' * 80}")
            print(f"SOURCES VIDEO TROUVEES: {len(sources)}")
            print(f"{'=' * 80}\n")

            video_urls = []

            for i, source in enumerate(sources, 1):
                quality = source.get("quality", "N/A")
                url = source.get("url", "")
                size = int(source.get("size", 0))
                size_mb = size / (1024 * 1024)
                format_type = source.get("format", "N/A")
                source_name = source.get("source", "N/A")

                print(f"[{i}] Qualite: {quality}p")
                print(f"    Source: {source_name}")
                print(f"    Format: {format_type}")
                print(f"    Taille: {size_mb:.2f} MB")

                # Decoder l'URL du proxy pour obtenir l'URL réelle
                if "proxy.vive-e69.workers.dev/proxy?url=" in url:
                    # Extraire l'URL encodée
                    encoded_url = url.split("proxy?url=")[1].split("&headers=")[0]
                    real_url = urllib.parse.unquote(encoded_url)

                    print(f"    URL proxy: {url[:80]}...")
                    print(f"    URL reelle: {real_url}")
                else:
                    real_url = url
                    print(f"    URL: {url}")

                print()

                video_urls.append(
                    {
                        "quality": quality,
                        "real_url": real_url,
                        "proxy_url": url,
                        "size_mb": size_mb,
                        "format": format_type,
                        "source": source_name,
                    }
                )

            # Captions si disponibles
            if "captions" in data["data"]:
                captions = data["data"]["captions"]
                print(f"\n{'=' * 80}")
                print(f"SOUS-TITRES: {len(captions)}")
                print(f"{'=' * 80}\n")

                for caption in captions:
                    print(f"Langue: {caption.get('label', 'N/A')}")
                    print(f"URL: {caption.get('file', 'N/A')}\n")

            # Sauvegarder dans un fichier
            output_file = "/home/kraus_user/vid/video_sources.json"
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(
                    {"movie_id": movie_id, "sources": video_urls, "raw_data": data},
                    f,
                    indent=2,
                    ensure_ascii=False,
                )

            print(f"{'=' * 80}")
            print(f"Donnees sauvegardees dans: {output_file}")
            print(f"{'=' * 80}\n")

            # Afficher la meilleure qualité
            best = max(video_urls, key=lambda x: x["quality"])
            print(f"MEILLEURE QUALITE: {best['quality']}p ({best['size_mb']:.2f} MB)")
            print(f"URL: {best['real_url']}\n")

            return best["proxy_url"]

        else:
            print("Erreur: Pas de sources video dans la reponse")
            return []

    except requests.exceptions.RequestException as e:
        print(f"Erreur requete: {e}")
        return []
    except json.JSONDecodeError as e:
        print(f"Erreur parsing JSON: {e}")
        return []


def mpv_start(url):
    import subprocess

    referrer = "https://www.rivestream.app/"
    subprocess.run(["mpv", f"--referrer={referrer}", url])


def download_video(url, output_path, headers=None):
    """
    Telecharger une video
    """
    if headers is None:
        headers = {
            "Referer": "https://fmoviesunblocked.net/",
            "Origin": "https://fmoviesunblocked.net",
        }

    print(f"Telechargement de: {url}")
    print(f"Vers: {output_path}")

    try:
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()

        total_size = int(response.headers.get("content-length", 0))

        with open(output_path, "wb") as f:
            downloaded = 0
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size:
                        percent = (downloaded / total_size) * 100
                        print(f"\rProgression: {percent:.1f}%", end="")

        print(f"\nTelechargement termine: {output_path}")

    except Exception as e:
        print(f"\nErreur telechargement: {e}")


if __name__ == "__main__":
    url = extract_video_urls()
    mpv_start(url)
