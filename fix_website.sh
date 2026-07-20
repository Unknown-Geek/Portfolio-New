#!/usr/bin/env bash
set -e

# ==============================================================================
# Script: fix_website.sh
# Purpose:
#   1. Clone www.shravanpandala.framer.website using HTTrack.
#   2. Move the website content to the root URL (placing index.html at root).
#   3. Remove the "Made with Framer" badge via MutationObserver & CSS.
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CDIR="$SCRIPT_DIR"
TEMP_DIR="$CDIR/_temp_httrack"
DEFAULT_TARGET_URL="https://www.shravanpandala.framer.website"

echo "=== Running Website Mirror & Fix Script ==="

# Helper function for inline string replacement across macOS and Linux
sed_replace() {
    local search="$1"
    local replace="$2"
    local file="$3"
    perl -pi -e "s|\Q$search\E|$replace|g" "$file" 2>/dev/null || true
}

# Function to check if index.html is HTTrack launcher index stub
is_httrack_launcher() {
    local html_file="$1"
    if [ ! -f "$html_file" ]; then
        return 1
    fi
    if grep -q "<title>Local index - HTTrack Website Copier</title>" "$html_file" 2>/dev/null || \
       grep -q 'content="HTTrack is an easy-to-use website mirror utility' "$html_file" 2>/dev/null; then
        return 0 # It IS launcher stub
    fi
    return 1 # Not launcher
}

# Function to locate the primary site directory containing real index.html
find_site_directory() {
    local search_base="$1"
    local best_dir=""
    local max_size=0

    for d in "$search_base"/*; do
        if [ -d "$d" ]; then
            local bname
            bname=$(basename "$d")
            case "$bname" in
                "hts-cache"|"_temp_httrack"|".git"|"node_modules"|"v"|"scratch") continue ;;
            esac

            if [ -f "$d/index.html" ]; then
                if ! is_httrack_launcher "$d/index.html"; then
                    local fsize
                    fsize=$(wc -c < "$d/index.html" 2>/dev/null || echo 0)
                    if [ "$fsize" -gt "$max_size" ]; then
                        max_size="$fsize"
                        best_dir="$d"
                    fi
                fi
            fi
        fi
    done
    echo "$best_dir"
}

# 1. Clone website using HTTrack
SITE_DIR=$(find_site_directory "$CDIR")

if [ -n "$SITE_DIR" ] && [ -d "$SITE_DIR" ]; then
    echo "1. Found existing local domain folder with website content: $(basename "$SITE_DIR")"
else
    echo "1. Cloning website using HTTrack from $DEFAULT_TARGET_URL..."
    if ! command -v httrack &> /dev/null; then
        echo "Error: httrack command not found. Please install httrack or ensure it is in PATH."
        exit 1
    fi

    TARGET_URL="${1:-$DEFAULT_TARGET_URL}"
    echo "Target URL: $TARGET_URL"

    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"

    httrack "$TARGET_URL" \
        -O "$TEMP_DIR" \
        "+*.shravanpandala.framer.website/*" \
        "+*.framerusercontent.com/*" \
        -N0 -%v -q || true

    SITE_DIR=$(find_site_directory "$TEMP_DIR")

    if [ -z "$SITE_DIR" ] || [ ! -d "$SITE_DIR" ]; then
        if [ "$TARGET_URL" != "https://shravanpandala.framer.website" ]; then
            echo "Retrying download with https://shravanpandala.framer.website..."
            rm -rf "$TEMP_DIR"
            mkdir -p "$TEMP_DIR"
            httrack "https://shravanpandala.framer.website" \
                -O "$TEMP_DIR" \
                "+*.shravanpandala.framer.website/*" \
                "+*.framerusercontent.com/*" \
                -N0 -%v -q || true
            SITE_DIR=$(find_site_directory "$TEMP_DIR")
        fi
    fi

    if [ -z "$SITE_DIR" ] || [ ! -d "$SITE_DIR" ]; then
        echo "Error: Could not locate mirrored site directory in $TEMP_DIR"
        exit 1
    fi

    for d in "$TEMP_DIR"/*; do
        if [ -d "$d" ]; then
            basename_d=$(basename "$d")
            case "$basename_d" in
                "hts-cache"|"hts-log.txt"|"backblue.gif"|"fade.gif"|"index.html"|"_temp_httrack") continue ;;
            esac
            if [ "$d" != "$SITE_DIR" ]; then
                echo "Copying additional asset/subdomain directory: $basename_d"
                cp -R "$d" "$CDIR/"
            fi
        fi
    done
fi

# 2. Move website content to project root
echo "2. Moving website content to root directory..."

rm -rf "$CDIR/backblue.gif" \
       "$CDIR/fade.gif" \
       "$CDIR/hts-cache" \
       "$CDIR/hts-log.txt" \
       "$CDIR/hts-ioinfo.txt" \
       "$CDIR/v"

if [ -f "$CDIR/index.html" ]; then
    if is_httrack_launcher "$CDIR/index.html"; then
        rm -f "$CDIR/index.html"
    fi
fi

if [ "$SITE_DIR" != "$CDIR" ]; then
    find "$SITE_DIR" -mindepth 1 -maxdepth 1 -exec cp -R {} "$CDIR/" \;
    rm -rf "$SITE_DIR"
fi

if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

# 3. Fix relative links and domain rewrites
echo "3. Cleaning link references in HTML files..."
find "$CDIR" -maxdepth 2 -name "*.html" -type f | while read -r html_file; do
    sed_replace "https://www.shravanpandala.framer.website/" "./" "$html_file"
    sed_replace "https://shravanpandala.framer.website/" "./" "$html_file"
    sed_replace "https://www.shravanpandala.me/" "./" "$html_file"
    sed_replace "https://shravanpandala.me/" "./" "$html_file"
    sed_replace "../resume.index.html" "https://resume.shravanpandala.me" "$html_file"
    sed_replace "href=\"resume.index.html\"" "href=\"https://resume.shravanpandala.me\"" "$html_file"
    sed_replace "../github.index.html" "https://github.com/Unknown-Geek" "$html_file"
    sed_replace "href=\"github.index.html\"" "href=\"https://github.com/Unknown-Geek\"" "$html_file"
    sed_replace "../linkedin.index.html" "https://linkedin.com/in/shravanpandala" "$html_file"
    sed_replace "href=\"linkedin.index.html\"" "href=\"https://linkedin.com/in/shravanpandala\"" "$html_file"
    sed_replace "../behance.index.html" "https://behance.net/shravanpandala2005" "$html_file"
    sed_replace "href=\"behance.index.html\"" "href=\"https://behance.net/shravanpandala2005\"" "$html_file"
    sed_replace "../dribbble.index.html" "https://dribbble.com/Shravan_Pandala" "$html_file"
    sed_replace "href=\"dribbble.index.html\"" "href=\"https://dribbble.com/Shravan_Pandala\"" "$html_file"
    sed_replace "../leetcode.index.html" "https://leetcode.com/B3x62eJk4a" "$html_file"
    sed_replace "href=\"leetcode.index.html\"" "href=\"https://leetcode.com/B3x62eJk4a\"" "$html_file"
done

# 4. Inject Framer Badge Removal Snippets
echo "4. Removing 'Made with Framer' badge..."
BADGE_INJECTION='<style id="remove-framer-badge">#framer-badge-container, #__framer-badge-container, #framer-badge, .framer-badge-container, a[href*="framer.com/?"], a[href*="framer.com?utm"], a[href="https://www.framer.com/"], a[href="https://framer.com/"] { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }</style><script id="remove-framer-badge-js">(function(){function r(){var s=["#framer-badge-container","#__framer-badge-container","#framer-badge",".framer-badge-container","a[href*=\"framer.com/?\"]","a[href*=\"framer.com?utm\"]"];s.forEach(function(q){document.querySelectorAll(q).forEach(function(e){e.remove();});});}document.addEventListener("DOMContentLoaded",r);window.addEventListener("load",r);new MutationObserver(r).observe(document.documentElement,{childList:true,subtree:true});})();</script>'

find "$CDIR" -maxdepth 2 -name "*.html" -type f | while read -r html_file; do
    sed_replace 'content="Made with Framer"' 'content="Shravan Pandala - Portfolio"' "$html_file"
    
    if ! grep -q "remove-framer-badge" "$html_file" 2>/dev/null; then
        perl -pi -e "s|</head>|${BADGE_INJECTION}\n</head>|i" "$html_file" 2>/dev/null || true
    fi
done

echo "=== Success! Website cloned to root ($CDIR) with Framer badge removed. ==="