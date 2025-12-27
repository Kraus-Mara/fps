from playwright.sync_api import sync_playwright
import os
import time
import threading
import sys
TIMEOUT = 5


def inspect_iframe_content(movie_id):
    urls = []
    url_found = threading.Event()
    timeout = 0
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
                    urls.append(url)
                    url_found.set()

        page.on("response", handle_response)
        html_path = os.path.abspath("temp.html")
        page.goto(f"file://{html_path}")

        while not url_found.is_set():
            page.wait_for_timeout(100)  # Wait 100ms
            timeout += 0.1 # Adds 100ms to the chrono
            if timeout >= TIMEOUT: # over TIMEOUT seconds : should break cause no url found
                break

        browser.close()
        p.stop()
    return urls if urls else exit("No URL found within the timeout period.")

def all_urls(movie_id):
    urls = inspect_iframe_content(movie_id)
    [print(urls) for url in urls]

def first_url(movie_id):
    urls = inspect_iframe_content(movie_id)
    print(urls[0])

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("nn")
        sys.exit(1)
    movie_id = sys.argv[1]
    urls = all_urls(movie_id) # 533535 ou 10466
    # url = first_url(movie_id)
