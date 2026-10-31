#most of this aliases are for arch linux

# Prefer paru, fall back to yay — keeps these helpers shareable across machines.
if command -v paru >/dev/null 2>&1; then
	AUR_HELPER=paru
elif command -v yay >/dev/null 2>&1; then
	AUR_HELPER=yay
else
	AUR_HELPER=
fi
export AUR_HELPER

# AUR scripts live in the shared dotfiles repo (not ~/Documenti).
DOTFILES_SCRIPTS="${DOTFILES_SCRIPTS:-$HOME/.dotfiles/scripts}"
AUR_WRAP="${AUR_WRAP:-$DOTFILES_SCRIPTS/aur-wrap}"
PKG_BIN="${PKG_BIN:-$DOTFILES_SCRIPTS/pkg}"
export DOTFILES_SCRIPTS AUR_WRAP

# Wrap paru/yay: on oracle-instantclient exact-version pin failures, offer aur-coinstall.
if [[ -n "$AUR_HELPER" && -x "$AUR_WRAP" ]]; then
	paru() {
		AUR_HELPER=paru "$AUR_WRAP" "$@"
	}
	yay() {
		AUR_HELPER=yay "$AUR_WRAP" "$@"
	}
fi

# Unified AUR helper (search|install|remove|autoremove|… or raw flags like -Syu)
aur() {
	if [[ -z "$AUR_HELPER" ]]; then
		echo "❌ No AUR helper found (install paru or yay)"
		return 1
	fi
	if [[ ! -x "$PKG_BIN" ]]; then
		echo "❌ pkg script missing: $PKG_BIN"
		return 1
	fi
	"$PKG_BIN" "$AUR_HELPER" "$@"
}

eos-update() {
	if [[ -z "$AUR_HELPER" ]]; then
		echo "❌ No AUR helper found (install paru or yay)"
		return 1
	fi
	# eos-update accepts --paru / --yay (same as --helper=<name>)
	command eos-update "--$AUR_HELPER" --descriptions "$@"
}

# commented, I created a command because of gnome update extensions
#eos-check() {
#	[[ -n "$AUR_HELPER" ]] || { echo "❌ No AUR helper found"; return 1; }
#	/usr/bin/checkupdates && command "$AUR_HELPER" -Qua
#}

alias ports='netstat -tulanp'

alias art="php artisan"

# alias ff="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
alias ff="fzf --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

alias service-status='SYSTEMD_COLORS=16 systemctl list-units --type=service --all --no-pager | grep --color=never -vE "systemd-|dracut-|initrd-|modprobe@|getty@|user@"'

mount() {
	if [ $# -eq 0 ] || [ "$1" = "-l" ] || [ "$1" = "--show-labels" ]; then
		command mount | column -t
	else
		command mount "$@"
	fi
}

eos-search() {
	if [[ -z "$AUR_HELPER" ]]; then
		echo "❌ No AUR helper found (install paru or yay)"
		return 1
	fi
	aur search "$@"
}

html() {
	local base_path="/srv/http"

	if ! [ -d "$base_path" ]; then
		base_path="/usr/share/nginx/html"
		if ! [ -d "$base_path" ]; then
			base_path="/var/www/html"
			if ! [ -d "$base_path" ]; then
				echo "❌ Not a valid directory found."
				exit 1
			fi
		fi
	fi

    if [ -n "$1" ] && [ -d "$base_path/$1" ]; then
    		cd "$base_path/$1"
    else
        cd /srv/http
    fi
}

# Porta nei dotfiles le impostazioni di noctalia cambiate dall'interfaccia:
# la shell scrive in ~/.local/state/noctalia/settings.toml, che non e' nel repo.
alias noctalia-sync="$DOTFILES_SCRIPTS/noctalia-sync"
