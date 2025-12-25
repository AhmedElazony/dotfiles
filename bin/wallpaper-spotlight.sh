#!/bin/bash

# Linux Spotlight Wallpaper Script
# Mimics Windows Spotlight for Hyprland/Wayland
# Requirements: swww, curl

# Configuration
WALLPAPER_DIR="$HOME/.local/share/wallpapers/spotlight"
CURRENT_WALLPAPER="$HOME/.local/share/wallpapers/current_wallpaper"
LOG_FILE="$HOME/.local/share/wallpapers/spotlight.log"
PROGRESS_FILE="$HOME/.local/share/wallpapers/spotlight_progress.txt"
MAX_WALLPAPERS=50 # Keep only last 50 wallpapers
TOTAL_PAGES=1227  # Total pages on the site (as observed)
BASE_URL="https://windows10spotlight.com"

# Create directories
mkdir -p "$WALLPAPER_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Logging
log_message() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Dependencies
check_dependencies() {
	local deps=("curl" "swww" "file")
	for dep in "${deps[@]}"; do
		if ! command -v "$dep" &>/dev/null; then
			log_message "ERROR: $dep is not installed. Install with your package manager."
			exit 1
		fi
	done

	if ! command -v identify &>/dev/null; then
		log_message "WARNING: ImageMagick not found. Install it for better resolution checks."
	fi

	# Allow headless downloads (do not exit if no display)
	if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
		log_message "WARNING: No graphical session detected. Will download, but won't set wallpaper."
	fi

	# Only warn about daemon; don't try to start it from here
	if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
		if ! pgrep -x "swww-daemon" >/dev/null; then
			log_message "WARNING: swww-daemon not running. Start it in your session (e.g., 'swww-daemon' then 'swww init')."
		fi
	fi
}

# Helpers
abs_url() {
	local u="$1"
	if [[ "$u" =~ ^https?:// ]]; then
		echo "$u"
	else
		u="${u#/}"
		echo "$BASE_URL/$u"
	fi
}

# Prefer original JPG (no -WxH) or largest -WxH; prefer jpeg over webp
pick_best_image_url() {
	local urls=("$@")
	local best=""
	local best_score=-1

	for u in "${urls[@]}"; do
		local ext_score=0
		[[ "$u" =~ \.jpe?g($|\?) ]] && ext_score=2
		[[ "$u" =~ \.webp($|\?) ]] && ext_score=1

		local size_score=0
		if [[ "$u" =~ -([0-9]+)x([0-9]+)\.(jpe?g|webp)(\?|$) ]]; then
			local w="${BASH_REMATCH[1]}"
			local h="${BASH_REMATCH[2]}"
			size_score=$((w * h))
		else
			# treat as original (no -WxH)
			size_score=2000000000
		fi

		local score=$((size_score * 10 + ext_score))
		if ((score > best_score)); then
			best_score=$score
			best="$u"
		fi
	done

	echo "$best"
}

# Progress
load_progress() {
	if [ -f "$PROGRESS_FILE" ]; then
		local progress
		progress=$(cat "$PROGRESS_FILE")
		local current_page current_index
		current_page=$(echo "$progress" | cut -d':' -f1)
		current_index=$(echo "$progress" | cut -d':' -f2)
		if [[ "$current_page" =~ ^[0-9]+$ ]] && [[ "$current_index" =~ ^[0-9]+$ ]]; then
			echo "$current_page:$current_index"
			return 0
		fi
	fi
	echo "1:0"
}

save_progress() {
	echo "$1:$2" >"$PROGRESS_FILE"
}

# Extract next image URL from listing page and a post index (sequential)
# Returns:
#  echo URL and exit 0 on success
#  exit 2 if post_index beyond the posts on that page (advance page)
#  exit 1 on fetch/parse failure (also advance page)
get_next_image_url() {
	local page="$1"
	local post_index="$2"

	local page_url="$BASE_URL/"
	if [ "$page" -gt 1 ]; then
		page_url="$BASE_URL/page/$page/"
	fi

	# Fetch listing page
	local page_html
	page_html=$(curl -s -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" "$page_url") || return 1
	[ -z "$page_html" ] && return 1

	# Collect post links (/images/<id>) absolute or relative
	# Use href="..."; tolerate optional trailing slash
	local post_urls=()
	while IFS= read -r href; do
		href="${href#href=\"}"
		href="${href%\"}"
		post_urls+=("$(abs_url "$href")")
	done < <(
		echo "$page_html" |
			grep -oE 'href="(/images/[0-9]+/?|https://windows10spotlight\.com/images/[0-9]+/?)"' |
			sort -u
	)

	if [ ${#post_urls[@]} -eq 0 ]; then
		# Try a simpler fallback: any absolute /images/<id>
		while IFS= read -r link; do
			post_urls+=("$link")
		done < <(echo "$page_html" | grep -oE 'https://windows10spotlight\.com/images/[0-9]+/?' | sort -u)
	fi

	if [ ${#post_urls[@]} -eq 0 ]; then
		return 1
	fi

	if [ "$post_index" -ge ${#post_urls[@]} ]; then
		return 2
	fi

	local post_url="${post_urls[$post_index]}"

	# Fetch post page
	local post_html
	post_html=$(curl -s -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" "$post_url") || return 1
	[ -z "$post_html" ] && return 1

	# Collect candidate image URLs
	local candidates=()

	# Absolute URLs in wp-content/uploads
	while IFS= read -r u; do
		candidates+=("$u")
	done < <(echo "$post_html" | grep -oE 'https://windows10spotlight\.com/wp-content/uploads/[^"<>[:space:]]*\.(jpe?g|webp)' | sort -u)

	# Relative URLs
	while IFS= read -r u; do
		candidates+=("$(abs_url "$u")")
	done < <(echo "$post_html" | grep -oE 'wp-content/uploads/[^"<>[:space:]]*\.(jpe?g|webp)' | sort -u)

	[ ${#candidates[@]} -eq 0 ] && return 1

	# Normalize to potential original (remove -WxH)
	local normalized=()
	for u in "${candidates[@]}"; do
		local v="$u"
		v="$(echo "$v" | sed -E 's/-[0-9]+x[0-9]+(\.(jpe?g|webp)(\?|$))/\1/')"
		normalized+=("$v")
	done

	# Deduplicate
	mapfile -t normalized < <(printf '%s\n' "${normalized[@]}" | sort -u)

	# Pick best
	local best
	best="$(pick_best_image_url "${normalized[@]}")"
	[ -z "$best" ] && return 1

	echo "$best"
	return 0
}

# Validate file is an image
validate_image() {
	local file_path="$1"
	[ ! -f "$file_path" ] || [ ! -s "$file_path" ] && return 1

	local file_type
	file_type=$(file -b --mime-type "$file_path" 2>/dev/null)
	if [[ "$file_type" =~ ^image/(jpeg|jpg|png|webp|bmp|tiff)$ ]]; then
		return 0
	fi

	local header
	header=$(hexdump -C "$file_path" | head -1 2>/dev/null)
	[[ "$header" =~ "ff d8 ff" ]] && return 0    # JPEG
	[[ "$header" =~ "89 50 4e 47" ]] && return 0 # PNG

	log_message "File validation failed: $file_type"
	return 1
}

# Resolution check
check_image_resolution() {
	local file_path="$1"

	if command -v identify &>/dev/null; then
		local dims width height
		dims=$(identify "$file_path" 2>/dev/null | awk '{print $3}')
		width="${dims%x*}"
		height="${dims#*x}"
		if [ -n "$width" ] && [ -n "$height" ] && [ "$width" -ge 1600 ] && [ "$height" -ge 900 ]; then
			return 0
		else
			log_message "Image too small: ${width}x${height}"
			return 1
		fi
	else
		local size
		size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
		[ -n "$size" ] && [ "$size" -gt 500000 ] && return 0
		log_message "File size too small: ${size:-unknown}"
		return 1
	fi
}

# Cleanup old wallpapers
clean_old_wallpapers() {
	local count
	count=$(ls -1 "$WALLPAPER_DIR"/*.jpg 2>/dev/null | wc -l)
	if [ "$count" -gt "$MAX_WALLPAPERS" ]; then
		log_message "Cleaning old wallpapers (keeping last $MAX_WALLPAPERS)"
		ls -t "$WALLPAPER_DIR"/*.jpg | tail -n +$((MAX_WALLPAPERS + 1)) | xargs rm -f
	fi
}

# Download next wallpaper sequentially
download_windows_spotlight() {
	local progress current_page current_index
	progress=$(load_progress)
	current_page=$(echo "$progress" | cut -d':' -f1)
	current_index=$(echo "$progress" | cut -d':' -f2)

	# Try current page plus next two pages at most
	local tries=0
	local image_url=""
	local status=1

	while [ $tries -lt 3 ] && [ -z "$image_url" ]; do
		status=0
		image_url="$(get_next_image_url "$current_page" "$current_index")" || status=$?

		case "$status" in
		0)
			# got URL
			;;
		2)
			# post index beyond posts -> next page
			current_page=$((current_page + 1))
			[ "$current_page" -gt "$TOTAL_PAGES" ] && current_page=1
			current_index=0
			tries=$((tries + 1))
			continue
			;;
		*)
			# page failed or empty -> next page
			current_page=$((current_page + 1))
			[ "$current_page" -gt "$TOTAL_PAGES" ] && current_page=1
			current_index=0
			tries=$((tries + 1))
			continue
			;;
		esac
		break
	done

	if [ -z "$image_url" ]; then
		log_message "No wallpaper URL found after checking $tries page(s)."
		save_progress "$current_page" "$current_index"
		return 1
	fi

	local ts random_num filename
	ts=$(date +%s)
	random_num=$((RANDOM % 9999))
	filename="$WALLPAPER_DIR/spotlight_p${current_page}_i${current_index}_${ts}_${random_num}.jpg"

	#   log_message "Downloading: $image_url"
	if curl -s -L \
		-H "Referer: $BASE_URL/" \
		-H "Accept: image/avif,image/webp,image/apng,image/*,*/*;q=0.8" \
		-A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" \
		-o "$filename" "$image_url"; then

		if validate_image "$filename" && check_image_resolution "$filename"; then
			current_index=$((current_index + 1))
			save_progress "$current_page" "$current_index"
			echo "$filename"
			return 0
		else
			log_message "Downloaded file failed validation. Skipping."
			rm -f "$filename"
			current_index=$((current_index + 1))
			save_progress "$current_page" "$current_index"
			return 1
		fi
	else
		log_message "HTTP download failed."
		current_index=$((current_index + 1))
		save_progress "$current_page" "$current_index"
		return 1
	fi
}

# Set wallpaper with swww (if session available)
set_wallpaper() {
	local image_file="$1"

	if [ ! -f "$image_file" ]; then
		log_message "ERROR: Image file not found: $image_file"
		return 1
	fi

	if ! validate_image "$image_file"; then
		log_message "ERROR: Invalid image file: $image_file"
		return 1
	fi

	if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
		log_message "No graphical session. Saved current path only."
		echo "$image_file" >"$CURRENT_WALLPAPER"
		return 0
	fi

	if ! pgrep -x "swww-daemon" >/dev/null; then
		log_message "ERROR: swww-daemon is not running."
		echo "$image_file" >"$CURRENT_WALLPAPER"
		return 1
	fi

	if ! swww query &>/dev/null; then
		log_message "ERROR: swww is not initialized. Run 'swww init' in your session."
		echo "$image_file" >"$CURRENT_WALLPAPER"
		return 1
	fi

	log_message "Setting wallpaper: $(basename "$image_file")"
	if swww img "$image_file" --transition-type wipe --transition-duration 1; then
		echo "$image_file" >"$CURRENT_WALLPAPER"
		log_message "Wallpaper set successfully."
		return 0
	else
		log_message "ERROR: Failed to set wallpaper with swww"
		echo "$image_file" >"$CURRENT_WALLPAPER"
		return 1
	fi
}

# Fallback: pick a random existing
get_random_existing() {
	local current=""
	[ -f "$CURRENT_WALLPAPER" ] && current=$(cat "$CURRENT_WALLPAPER")

	local arr=()
	for w in "$WALLPAPER_DIR"/*.jpg; do
		[ -f "$w" ] || continue
		[ "$w" = "$current" ] && continue
		if validate_image "$w"; then
			arr+=("$w")
		fi
	done

	if [ ${#arr[@]} -gt 0 ]; then
		echo "${arr[$((RANDOM % ${#arr[@]}))]}"
		return 0
	fi
	return 1
}

# Main
main() {
	log_message "Starting wallpaper update"
	check_dependencies
	clean_old_wallpapers

	local new_wallpaper=""
	log_message "Attempting to download from Windows Spotlight website..."
	new_wallpaper=$(download_windows_spotlight)

	if [ -z "$new_wallpaper" ]; then
		log_message "Download failed. Trying an existing wallpaper..."
		new_wallpaper=$(get_random_existing)
		[ -n "$new_wallpaper" ] && log_message "Using existing: $(basename "$new_wallpaper")"
	fi

	if [ -n "$new_wallpaper" ]; then
		set_wallpaper "$new_wallpaper"
	else
		log_message "ERROR: No wallpaper available to set"
		exit 1
	fi

	log_message "Wallpaper update completed"
}

# CLI
case "${1:-}" in
init)
	log_message "Initializing spotlight wallpaper"
	main
	;;
next)
	log_message "Manual wallpaper change requested"
	main
	;;
status)
	if [ -f "$CURRENT_WALLPAPER" ]; then
		current=$(cat "$CURRENT_WALLPAPER")
		echo "Current wallpaper: $(basename "$current")"
	else
		echo "Current wallpaper: (none)"
	fi
	echo "Wallpaper directory: $WALLPAPER_DIR"
	echo "Stored wallpapers: $(ls -1 "$WALLPAPER_DIR"/*.jpg 2>/dev/null | wc -l)"
	if [ -f "$PROGRESS_FILE" ]; then
		progress=$(load_progress)
		echo "Progress: page $(echo "$progress" | cut -d: -f1), post-index $(echo "$progress" | cut -d: -f2) of $TOTAL_PAGES pages"
	else
		echo "Progress: Not started"
	fi
	if pgrep -x "swww-daemon" >/dev/null; then
		echo "swww-daemon: Running"
		if swww query &>/dev/null; then
			echo "swww: Initialized"
		else
			echo "swww: Not initialized"
		fi
	else
		echo "swww-daemon: Not running"
	fi
	;;
reset)
	log_message "Resetting progress to page 1, index 0"
	save_progress 1 0
	;;
*)
	main
	;;
esac
