from playwright.sync_api import sync_playwright
import os
import time

TIMEOUT = 3


def inspect_iframe_content(movie_id):
    urls = []
    with open("temp.html", "w") as temp:
        temp.write("<iframe\n")
        temp.write(
            f'    src="https://www.rivestream.app/embed?type=movie&id={movie_id}" allowfullscreen>\n'
        )
        temp.write("</iframe>\n")
    temp.close()
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        def handle_response(response):
            url = response.url

            if "https://www.rivestream.app/api/" in url:
                if "service=" in url:
                    print(f"url d'accès : {url}")
                    urls.append(url)

        page.on("response", handle_response)
        html_path = os.path.abspath("temp.html")
        page.goto(f"file://{html_path}")
        time.sleep(TIMEOUT)
        browser.close()
    return urls


def id_to_urls(movie_id):
    return inspect_iframe_content(movie_id)


if __name__ == "__main__":
    urls = inspect_iframe_content(755898)
    [print(url) for url in urls]
