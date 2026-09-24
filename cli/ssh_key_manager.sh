#!/bin/bash
#
# ssh_key_manager.sh
#
# Interactive SSH key manager and public-key auto-deployer.
#
# - Lists every host from ~/.ssh/config and shows which key each one resolves to.
# - Adds new hosts to ~/.ssh/config from a user@host string.
# - Generates ed25519 keys.
# - Auto-deploys your public key to one host or all of them (ssh-copy-id), then
#   verifies passwordless login. Safe to re-run.
# - Sets/repairs the IdentityFile for a host, with a timestamped backup.
#
# Usage:
#   bash cli/ssh_key_manager.sh                 # interactive menu
#   bash cli/ssh_key_manager.sh --list
#   bash cli/ssh_key_manager.sh --add user@host[:port] [--name NAME] [--key PATH]
#   bash cli/ssh_key_manager.sh --generate NAME
#   bash cli/ssh_key_manager.sh --deploy HOST|all [--key PATH]
#   bash cli/ssh_key_manager.sh --verify HOST|all
#   bash cli/ssh_key_manager.sh --help
#
# Notes:
#   - Only the main ~/.ssh/config file is read; "Include" directives are not
#     followed (hosts kept in included files will not be listed).
#   - Wildcard host blocks (Host * / Host *.example.com) are skipped.
#

#-------------------------------------------------------
# Resolve repository paths (follow symlinks, like load_configs.sh)
#-------------------------------------------------------
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
	DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
	SOURCE=$(readlink "$SOURCE")
	[[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
CURRENT_SCRIPT_DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
REPO_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
repo_dir="$REPO_DIR"

# Load shared logging/menu helpers when available.
HELPER_SCRIPT="$REPO_DIR/scripts/install_modules/helpers.sh"
if [ -f "$HELPER_SCRIPT" ]; then
	source "$HELPER_SCRIPT"
else
	_log() { local level=$1; shift; echo "[$level] $*" >&2; }
	_header() { echo; echo "============================================================="; echo " $*"; echo "============================================================="; }
	ask_yes_no() {
		local question="$1"
		local prompt="[y/n]"
		while true; do
			read -rp "$question $prompt: " response
			case "$response" in
			[yY][eE][sS] | [yY]) return 0 ;;
			[nN][oO] | [nN]) return 1 ;;
			*) echo "Please answer yes or no." ;;
			esac
		done
	}
fi

#-------------------------------------------------------
# Configuration
#-------------------------------------------------------
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
DEFAULT_KEY="$SSH_DIR/id_ed25519"

C_RED=$'\033[0;31m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_BLUE=$'\033[0;34m'
C_BOLD=$'\033[1m'
C_RESET=$'\033[0m'

# Globals populated by load_hosts / _pick_hosts
HOSTS=()
PICKED=()

#-------------------------------------------------------
# Host discovery
#-------------------------------------------------------
load_hosts() {
	HOSTS=()
	if [ ! -f "$SSH_CONFIG" ]; then
		_log WARN "No SSH config found at '$SSH_CONFIG'."
		return 1
	fi

	mapfile -t HOSTS < <(awk '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*[Hh]ost[[:space:]]/ {
			n = split($0, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) {
				tok = parts[i]
				if (tok == "" || tok == "Host" || tok == "host") continue
				if (tok ~ /[*?!]/) continue
				print tok
			}
		}
	' "$SSH_CONFIG" | awk '!seen[$0]++')

	return 0
}

_host_field() {
	ssh -G "$1" 2>/dev/null | awk -v k="$2" 'tolower($1) == k { print $2; exit }'
}

_host_identity() {
	awk -v host="$1" '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*[Hh]ost[[:space:]]/ {
			inblock = 0
			n = split($0, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (parts[i] == host) inblock = 1
			next
		}
		inblock && $1 == "IdentityFile" { print $2 }
	' "$SSH_CONFIG" | paste -sd ',' -
}

_list_hosts() {
	if [ ${#HOSTS[@]} -eq 0 ]; then
		_log WARN "No usable hosts found in '$SSH_CONFIG'."
		return 1
	fi

	printf "%-4s %-24s %-30s %-12s %-5s %s\n" "#" "HOST" "HOSTNAME" "USER" "PORT" "KEY"
	printf "%-4s %-24s %-30s %-12s %-5s %s\n" "---" "----" "--------" "----" "----" "---"

	local i=1 h hostname user port key
	for h in "${HOSTS[@]}"; do
		hostname=$(_host_field "$h" hostname)
		user=$(_host_field "$h" user)
		port=$(_host_field "$h" port)
		key=$(_host_identity "$h")
		printf "%-4s %-24s %-30s %-12s %-5s %s\n" \
			"$i" "$h" "${hostname:-?}" "${user:-?}" "${port:-?}" "${key:-(default)}"
		i=$((i + 1))
	done
}

_pick_hosts() {
	PICKED=()
	if [ ${#HOSTS[@]} -eq 0 ]; then
		load_hosts
	fi
	if [ ${#HOSTS[@]} -eq 0 ]; then
		_log WARN "No hosts available."
		return 1
	fi

	_list_hosts
	echo
	read -rp "Select host(s) by number (space/comma separated), 'all', or Enter to cancel: " selection
	selection="${selection//,/ }"

	if [ -z "$selection" ]; then
		return 1
	fi

	if [ "$selection" = "all" ]; then
		PICKED=("${HOSTS[@]}")
		return 0
	fi

	local idx
	for idx in $selection; do
		if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#HOSTS[@]} ]; then
			PICKED+=("${HOSTS[$((idx - 1))]}")
		else
			_log WARN "Ignoring invalid selection: '$idx'"
		fi
	done

	[ ${#PICKED[@]} -gt 0 ]
}

#-------------------------------------------------------
# Key helpers
#-------------------------------------------------------
_ensure_ssh_dir() {
	if [ ! -d "$SSH_DIR" ]; then
		mkdir -p "$SSH_DIR"
		chmod 700 "$SSH_DIR"
		_log INFO "Created '$SSH_DIR' with 700 permissions."
	fi
}

_is_passwordless() {
	ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$1" true >/dev/null 2>&1
}

_default_pub() {
	local p="${SSH_PUBKEY:-$DEFAULT_KEY.pub}"
	if [ ! -f "$p" ]; then
		p=$(ls -1 "$SSH_DIR"/*.pub 2>/dev/null | head -n1)
	fi
	echo "$p"
}

_pick_pubkey() {
	local pubs=()
	mapfile -t pubs < <(ls -1 "$SSH_DIR"/*.pub 2>/dev/null)

	if [ ${#pubs[@]} -eq 0 ]; then
		_log ERROR "No public keys found in '$SSH_DIR'. Generate one first (menu option 2)."
		return 1
	fi

	if [ ${#pubs[@]} -eq 1 ]; then
		echo "${pubs[0]}"
		return 0
	fi

	echo "Available public keys:" >&2
	local i=1 p
	for p in "${pubs[@]}"; do
		echo "  $i) $(basename "$p")" >&2
		i=$((i + 1))
	done

	local selection
	read -rp "Choose key [1]: " selection
	selection="${selection:-1}"

	if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#pubs[@]} ]; then
		echo "${pubs[$((selection - 1))]}"
	else
		_log ERROR "Invalid key selection."
		return 1
	fi
}

#-------------------------------------------------------
# Actions
#-------------------------------------------------------
generate_key() {
	_ensure_ssh_dir

	local name
	read -rp "Key name (without path, e.g. id_ed25519): " name
	name="${name:-id_ed25519}"
	local path="$SSH_DIR/$name"

	if [ -f "$path" ]; then
		if ! ask_yes_no "Key '$name' already exists. Overwrite?"; then
			_log INFO "Cancelled."
			return 0
		fi
	fi

	if ssh-keygen -t ed25519 -f "$path" -C "$USER@$(hostname)"; then
		_log SUCCESS "Generated '$path' (and '$path.pub')."
	else
		_log ERROR "Failed to generate key '$name'."
		return 1
	fi
}

deploy_key_to() {
	local host="$1"
	local pub="$2"

	if _is_passwordless "$host"; then
		_log INFO "'$host' already authenticates with a key — skipping."
		return 0
	fi

	_log INFO "Deploying '$(basename "$pub")' to '$host' (you may be prompted for a password once)..."

	if command -v ssh-copy-id >/dev/null 2>&1; then
		if ! ssh-copy-id -i "$pub" "$host"; then
			_log ERROR "ssh-copy-id failed for '$host'."
			return 1
		fi
	else
		_log WARN "'ssh-copy-id' not found; using manual fallback."
		if ! ssh "$host" 'umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys' <"$pub"; then
			_log ERROR "Manual key install failed for '$host'."
			return 1
		fi
	fi

	if _is_passwordless "$host"; then
		_log SUCCESS "Verified: passwordless login to '$host' works."
		return 0
	else
		_log WARN "Key installed on '$host', but passwordless login is not confirmed yet."
		return 1
	fi
}

deploy_flow() {
	if ! _pick_hosts; then
		_log INFO "Cancelled."
		return 0
	fi

	local pub
	pub=$(_pick_pubkey) || return 0

	echo
	_log INFO "Using public key: $pub"

	local h
	for h in "${PICKED[@]}"; do
		deploy_key_to "$h" "$pub"
	done
}

run_deploy_targets() {
	local target="$1"
	local pub="$2"

	load_hosts
	if [ ${#HOSTS[@]} -eq 0 ]; then
		_log ERROR "No hosts available."
		return 1
	fi

	local targets=()
	if [ "$target" = "all" ]; then
		targets=("${HOSTS[@]}")
	else
		targets=("$target")
	fi

	local h
	for h in "${targets[@]}"; do
		deploy_key_to "$h" "$pub"
	done
}

verify_flow() {
	if ! _pick_hosts; then
		_log INFO "Cancelled."
		return 0
	fi
	_report_login "${PICKED[@]}"
}

run_verify_targets() {
	local target="$1"
	load_hosts
	if [ ${#HOSTS[@]} -eq 0 ]; then
		_log ERROR "No hosts available."
		return 1
	fi

	local targets=()
	if [ "$target" = "all" ]; then
		targets=("${HOSTS[@]}")
	else
		targets=("$target")
	fi

	_report_login "${targets[@]}"
}

_report_login() {
	local targets=("$@")
	local h ok=0 fail=0
	printf "%-24s %s\n" "HOST" "RESULT"
	printf "%-24s %s\n" "----" "------"
	for h in "${targets[@]}"; do
		if _is_passwordless "$h"; then
			printf "${C_GREEN}%-24s %s${C_RESET}\n" "$h" "OK (passwordless)"
			ok=$((ok + 1))
		else
			printf "${C_RED}%-24s %s${C_RESET}\n" "$h" "FAILED"
			fail=$((fail + 1))
		fi
	done
	echo
	_log INFO "$ok reachable, $fail failed."
}

set_identity() {
	if ! _pick_hosts; then
		_log INFO "Cancelled."
		return 0
	fi

	local host="${PICKED[0]}"
	if [ ${#PICKED[@]} -gt 1 ]; then
		_log WARN "Only the first selected host ('$host') will be updated."
	fi

	local key
	read -rp "Private key path for '$host' [$DEFAULT_KEY]: " key
	key="${key:-$DEFAULT_KEY}"
	key="${key/#\~/$HOME}"

	if [ ! -f "$key" ]; then
		_log WARN "Key file '$key' does not exist."
		if ! ask_yes_no "Write it to the config anyway?"; then
			return 0
		fi
	fi

	_ensure_ssh_dir
	[ -f "$SSH_CONFIG" ] || : >"$SSH_CONFIG"

	local backup="$SSH_DIR/config.bak-$(date +%Y%m%d_%H%M%S)"
	cp "$SSH_CONFIG" "$backup"
	chmod 600 "$backup"
	_log INFO "Backed up config to '$backup'."

	local tmp
	tmp=$(mktemp)
	awk -v host="$host" -v key="$key" '
		BEGIN { inblock = 0; inserted = 0; found = 0 }
		/^[[:space:]]*#/ { print; next }
		/^[[:space:]]*[Hh]ost[[:space:]]/ {
			if (inblock && !inserted) { print "    IdentityFile " key; inserted = 1 }
			inblock = 0
			n = split($0, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) {
				if (parts[i] == host) { inblock = 1; found = 1 }
			}
			print
			next
		}
		inblock && !inserted && $1 == "IdentityFile" {
			print "    IdentityFile " key
			inserted = 1
			next
		}
		{ print }
		END {
			if (inblock && !inserted) { print "    IdentityFile " key }
			if (!found) { print ""; print "Host " host; print "    IdentityFile " key }
		}
	' "$SSH_CONFIG" >"$tmp"

	if [ -s "$tmp" ]; then
		mv "$tmp" "$SSH_CONFIG"
		chmod 600 "$SSH_CONFIG"
		_log SUCCESS "IdentityFile for '$host' set to '$key'."
	else
		rm -f "$tmp"
		_log ERROR "Failed to update '$SSH_CONFIG'."
		return 1
	fi
}

_host_exists() {
	local alias="$1"
	[ -f "$SSH_CONFIG" ] || return 1
	awk -v host="$alias" '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*[Hh]ost[[:space:]]/ {
			n = split($0, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (parts[i] == host) found = 1
		}
		END { exit(found ? 0 : 1) }
	' "$SSH_CONFIG"
}

_remove_host_block() {
	local alias="$1"
	local tmp
	tmp=$(mktemp)
	if awk -v host="$alias" '
		BEGIN { inblock = 0 }
		/^[[:space:]]*#/ { if (!inblock) print; next }
		/^[[:space:]]*[Hh]ost[[:space:]]/ {
			inblock = 0
			n = split($0, parts, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (parts[i] == host) inblock = 1
			if (!inblock) print
			next
		}
		{ if (!inblock) print }
	' "$SSH_CONFIG" >"$tmp"; then
		cat -s "$tmp" >"$tmp.squeezed"
		mv "$tmp.squeezed" "$tmp"
		mv "$tmp" "$SSH_CONFIG"
		chmod 600 "$SSH_CONFIG"
	else
		rm -f "$tmp" "$tmp.squeezed"
		return 1
	fi
}

_append_host_block() {
	local alias="$1" host="$2" user="$3" port="$4" key="$5"

	# Drop trailing blank lines so the separator below is exactly one blank line.
	if [ -s "$SSH_CONFIG" ]; then
		local stripped
		stripped=$(mktemp)
		awk '
			{ lines[NR] = $0 }
			END {
				last = NR
				while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
				for (i = 1; i <= last; i++) print lines[i]
			}
		' "$SSH_CONFIG" >"$stripped"
		mv "$stripped" "$SSH_CONFIG"
	fi

	{
		[ -s "$SSH_CONFIG" ] && echo ""
		echo "Host $alias"
		echo "    HostName $host"
		echo "    User $user"
		if [ -n "$port" ] && [ "$port" != "22" ]; then
			echo "    Port $port"
		fi
		if [ -n "$key" ]; then
			echo "    IdentityFile $key"
		fi
	} >>"$SSH_CONFIG"
	chmod 600 "$SSH_CONFIG"
}

# Parses "user@host:port", "user@host", "host:port" or "host" into the globals
# TARGET_USER / TARGET_HOST / TARGET_PORT.
_parse_target() {
	local input="${1// /}"
	TARGET_USER=""
	TARGET_HOST=""
	TARGET_PORT=""

	if [[ "$input" == *"@"* ]]; then
		TARGET_USER="${input%%@*}"
		input="${input#*@}"
	fi

	if [[ "$input" == *":"* ]]; then
		TARGET_HOST="${input%%:*}"
		TARGET_PORT="${input##*:}"
	else
		TARGET_HOST="$input"
	fi

	[ -n "$TARGET_USER" ] || TARGET_USER="$USER"
	[ -n "$TARGET_HOST" ]
}

_selected_key_to_path() {
	# $1 = selection (number or path); echoes a private key path or nothing.
	local selection="$1"
	local available=()
	mapfile -t available < <(ls -1 "$SSH_DIR"/*.pub 2>/dev/null)

	if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#available[@]} ]; then
		echo "$SSH_DIR/$(basename "${available[$((selection - 1))]}" .pub)"
	elif [ -n "$selection" ]; then
		echo "${selection/#\~/$HOME}"
	fi
}

# Adds (or replaces) a host block. Args: INPUT [NAME] [KEY]
_add_host() {
	local input="$1"
	local name="${2:-}"
	local key="${3:-}"

	if ! _parse_target "$input"; then
		_log ERROR "Could not parse '$input'. Expected user@host or host."
		return 1
	fi
	local user="$TARGET_USER" host="$TARGET_HOST" port="$TARGET_PORT"

	if [ -z "$name" ]; then
		read -rp "Name for this host [$host]: " name
		name="${name:-$host}"
	fi
	name="${name//[[:space:]]/}"
	if [ -z "$name" ]; then
		_log ERROR "Host name cannot be empty."
		return 1
	fi
	if [[ "$name" == *[*?!]* ]]; then
		_log ERROR "Host name cannot contain wildcard characters (* ? !)."
		return 1
	fi

	if [ -z "$key" ]; then
		local available=()
		mapfile -t available < <(ls -1 "$SSH_DIR"/*.pub 2>/dev/null)
		if [ ${#available[@]} -gt 0 ]; then
			echo "IdentityFile (blank = default):"
			local i=1 p
			for p in "${available[@]}"; do
				echo "  $i) $(basename "$p" .pub)"
				i=$((i + 1))
			done
			local selection
			read -rp "Choose key number, a key path, or leave blank: " selection
			key="$(_selected_key_to_path "$selection")"
		fi
	fi

	if _host_exists "$name"; then
		_log WARN "Host '$name' already exists in '$SSH_CONFIG'."
		if ! ask_yes_no "Replace the existing entry?"; then
			read -rp "Enter a different name (blank to cancel): " name
			name="${name//[[:space:]]/}"
			if [ -z "$name" ] || _host_exists "$name"; then
				_log INFO "Cancelled."
				return 0
			fi
		fi
	fi

	echo
	echo "About to add to $SSH_CONFIG:"
	echo
	echo "Host $name"
	echo "    HostName $host"
	echo "    User $user"
	if [ -n "$port" ] && [ "$port" != "22" ]; then
		echo "    Port $port"
	fi
	if [ -n "$key" ]; then
		echo "    IdentityFile $key"
	fi
	echo
	if ! ask_yes_no "Add this host?"; then
		_log INFO "Cancelled."
		return 0
	fi

	_ensure_ssh_dir
	[ -f "$SSH_CONFIG" ] || : >"$SSH_CONFIG"

	local backup="$SSH_DIR/config.bak-$(date +%Y%m%d_%H%M%S)"
	cp "$SSH_CONFIG" "$backup"
	chmod 600 "$backup"
	_log INFO "Backed up config to '$backup'."

	if _host_exists "$name"; then
		_remove_host_block "$name"
	fi
	_append_host_block "$name" "$host" "$user" "$port" "$key"
	_log SUCCESS "Added host '$name' -> ${user}@${host}${port:+:$port}."

	if ask_yes_no "Deploy your public key to '$host' now?"; then
		local pub
		pub="$(_default_pub)"
		if [ -f "$pub" ]; then
			deploy_key_to "$name" "$pub"
		else
			_log WARN "No public key found to deploy. Generate one first (menu option 2)."
		fi
	fi

	if ask_yes_no "Test passwordless login to '$name' now?"; then
		_report_login "$name"
	fi
}

add_host_flow() {
	local input
	read -rp "Host to add (user@host[:port], or just host): " input
	if [ -z "$input" ]; then
		_log INFO "Cancelled."
		return 0
	fi
	_add_host "$input"
}

show_keys() {
	_header "SSH Keys"

	echo "Key files in $SSH_DIR:"
	local f found=0
	for f in "$SSH_DIR"/*.pub; do
		[ -f "$f" ] || continue
		found=1
		printf "  %-28s %s\n" "$(basename "$f")" "$(ssh-keygen -lf "$f" 2>/dev/null)"
	done
	[ "$found" -eq 0 ] && echo "  (none)"

	echo
	echo "Keys loaded in ssh-agent:"
	if [ -n "$SSH_AUTH_SOCK" ]; then
		if ! ssh-add -l 2>&1 | sed 's/^/  /'; then
			echo "  (agent has no keys loaded)"
		fi
	else
		echo "  (no ssh-agent running — SSH_AUTH_SOCK is unset)"
	fi
}

#-------------------------------------------------------
# Interactive menu
#-------------------------------------------------------
main() {
	_header "SSH Key Manager"
	echo "Manage SSH keys and auto-deploy your public key to hosts in $SSH_CONFIG."

	while true; do
		load_hosts
		echo
		echo "1) List hosts and their keys"
		echo "2) Generate a new key (ed25519)"
		echo "3) Deploy my public key to host(s)"
		echo "4) Set/repair IdentityFile for a host"
		echo "5) Test passwordless login for host(s)"
		echo "6) Show keys and agent status"
		echo "7) Add a new host to ~/.ssh/config"
		echo "8) Exit"
		echo
		read -rp "Choose an option: " choice

		case "$choice" in
		1) _header "Hosts"; _list_hosts ;;
		2) _header "Generate Key"; generate_key ;;
		3) _header "Deploy Public Key"; deploy_flow ;;
		4) _header "Set IdentityFile"; set_identity ;;
		5) _header "Test Passwordless Login"; verify_flow ;;
		6) show_keys ;;
		7) _header "Add Host"; add_host_flow ;;
		8)
			echo "Bye."
			break
			;;
		*) echo "Invalid option. Please try again." ;;
		esac
		echo
	done
}

usage() {
	sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
}

#-------------------------------------------------------
# Entry point
#-------------------------------------------------------
action="${1:-}"

case "$action" in
"" | --menu)
	main
	;;
--help | -h)
	usage
	;;
--list)
	load_hosts
	_list_hosts
	;;
--add)
	if [ -z "${2:-}" ]; then
		_log ERROR "Usage: $0 --add user@host[:port] [--name NAME] [--key PATH]"
		exit 1
	fi
	add_target="$2"
	shift 2
	add_name=""
	add_key=""
	while [ $# -gt 0 ]; do
		case "$1" in
		--name)
			add_name="$2"
			shift 2
			;;
		--key)
			add_key="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done
	_add_host "$add_target" "$add_name" "$add_key"
	;;
--generate)
	if [ -z "${2:-}" ]; then
		_log ERROR "Usage: $0 --generate NAME"
		exit 1
	fi
	_ensure_ssh_dir
	if [ -f "$SSH_DIR/$2" ]; then
		_log ERROR "Key '$2' already exists at '$SSH_DIR/$2'."
		exit 1
	fi
	if ssh-keygen -t ed25519 -f "$SSH_DIR/$2" -C "$USER@$(hostname)"; then
		_log SUCCESS "Generated '$SSH_DIR/$2' (and '$SSH_DIR/$2.pub')."
	else
		_log ERROR "Failed to generate key '$2'."
		exit 1
	fi
	;;
--deploy)
	if [ -z "${2:-}" ]; then
		_log ERROR "Usage: $0 --deploy HOST|all [--key PATH]"
		exit 1
	fi
	target="$2"
	shift 2
	pub="$(_default_pub)"
	while [ $# -gt 0 ]; do
		case "$1" in
		--key)
			pub="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done
	if [ ! -f "$pub" ]; then
		_log ERROR "Public key not found: '$pub'. Use --key PATH or generate a key first."
		exit 1
	fi
	run_deploy_targets "$target" "$pub"
	;;
--verify)
	if [ -z "${2:-}" ]; then
		_log ERROR "Usage: $0 --verify HOST|all"
		exit 1
	fi
	run_verify_targets "$2"
	;;
*)
	_log ERROR "Unknown option: '$action'"
	usage
	exit 1
	;;
esac
