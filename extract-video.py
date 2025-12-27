#!/usr/bin/env python3
"""
Extract video URL from rivestream by intercepting API calls
"""

import sys
import json
import re
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
from urllib.parse import urlparse, parse_qs

def extract_video_url(url):
    """Extract video URL by intercepting rivestream API calls"""
    api_url = None
    video_url = None
    
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(headless=True)
            context = browser.new_context(
                user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                viewport={'width': 1920, 'height': 1080}
            )
            page = context.new_page()
            
            # Intercept network requests to find the API call
            def handle_request(request):
                nonlocal api_url
                req_url = request.url
                
                # Detect the backendfetch API call
                if 'rivestream.app/api/backendfetch' in req_url and 'requestID=movieVideoProvider' in req_url:
                    api_url = req_url
                    print(f"API URL interceptée: {api_url}", file=sys.stderr)
            
            # Intercept responses to get JSON data
            def handle_response(response):
                nonlocal video_url, api_url
                
                # Check if this is the API response we're looking for
                if response.url == api_url or ('rivestream.app/api/backendfetch' in response.url):
                    try:
                        if response.status == 200:
                            content_type = response.headers.get('content-type', '')
                            if 'json' in content_type.lower():
                                json_data = response.json()
                                print(f"Réponse JSON reçue: {json.dumps(json_data, indent=2)}", file=sys.stderr)
                                
                                # Extract video URL from various possible JSON structures
                                video_url = extract_video_from_json(json_data)
                                
                    except Exception as e:
                        print(f"Erreur lors du parsing JSON: {e}", file=sys.stderr)
            
            page.on('request', handle_request)
            page.on('response', handle_response)
            
            # Navigate to page
            print(f"Navigation vers: {url}", file=sys.stderr)
            page.goto(url, wait_until='networkidle', timeout=60000)
            
            # Wait for JavaScript to execute and make API calls
            page.wait_for_timeout(10000)
            
            # If we got the API URL but not the video URL, make the request manually
            if api_url and not video_url:
                print("Requête manuelle à l'API...", file=sys.stderr)
                response = context.request.get(api_url)
                if response.status == 200:
                    json_data = response.json()
                    print(f"Réponse manuelle: {json.dumps(json_data, indent=2)}", file=sys.stderr)
                    video_url = extract_video_from_json(json_data)
            
            browser.close()
            
        except PlaywrightTimeout:
            print("Timeout lors du chargement de la page", file=sys.stderr)
        except Exception as e:
            print(f"Erreur: {e}", file=sys.stderr)
    
    return video_url

def extract_video_from_json(data):
    """Extract video URL from JSON response"""
    
    # Common paths where video URLs might be
    possible_paths = [
        'url',
        'video_url',
        'videoUrl',
        'stream_url',
        'streamUrl',
        'source',
        'src',
        'file',
        'link',
        'playlist',
        'm3u8',
        'data.url',
        'data.stream',
        'result.url',
        'streams.0.url',
    ]
    
    def get_nested(obj, path):
        """Get nested value from dict using dot notation"""
        keys = path.split('.')
        val = obj
        for key in keys:
            if isinstance(val, dict):
                val = val.get(key)
            elif isinstance(val, list) and key.isdigit():
                try:
                    val = val[int(key)]
                except (IndexError, ValueError):
                    return None
            else:
                return None
        return val
    
    # Try common paths
    for path in possible_paths:
        val = get_nested(data, path)
        if val and isinstance(val, str) and ('http' in val or val.startswith('//')):
            return val
    
    # Deep search for URLs in the entire JSON structure
    def find_urls(obj, depth=0):
        if depth > 10:  # Prevent infinite recursion
            return None
        
        if isinstance(obj, dict):
            for key, value in obj.items():
                if isinstance(value, str) and ('http' in value or value.startswith('//')):
                    # Check if it looks like a video URL
                    if any(ext in value.lower() for ext in ['.m3u8', '.mp4', '.webm', 'stream', 'video', 'playlist']):
                        return value
                result = find_urls(value, depth + 1)
                if result:
                    return result
        elif isinstance(obj, list):
            for item in obj:
                result = find_urls(item, depth + 1)
                if result:
                    return result
        
        return None
    
    return find_urls(data)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: extract-video.py <url>", file=sys.stderr)
        sys.exit(1)
    
    url = sys.argv[1]
    video_url = extract_video_url(url)
    
    if video_url:
        # Clean up URL if needed
        if video_url.startswith('//'):
            video_url = 'https:' + video_url
        print(video_url)
    else:
        print("Aucune URL vidéo trouvée", file=sys.stderr)
        sys.exit(1)
