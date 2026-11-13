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

alias ports='netstat -tulanp'

alias art="php artisan"

# alias ff="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
alias ff="fzf --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Colori fzf generati dal template noctalia: va sourciato dopo le altre
# opzioni, perche' accoda i colori a FZF_DEFAULT_OPTS.
[[ -r "$HOME/.config/fzf/themes/noctalia.sh" ]] && source "$HOME/.config/fzf/themes/noctalia.sh"

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

# Web root of the projects: $HOME-independent, first existing directory among
# $HTML_BASE_PATH (if set), /srv/http, /usr/share/nginx/html, /var/www/html.
_html_base() {
	local dir
	for dir in "$HTML_BASE_PATH" /srv/http /usr/share/nginx/html /var/www/html; do
		if [ -n "$dir" ] && [ -d "$dir" ]; then
			printf '%s' "$dir"
			return 0
		fi
	done
	return 1
}

html() {
	local base_path
	base_path=$(_html_base) || {
		echo "❌ Not a valid directory found."
		return 1
	}

	if [ -n "$1" ] && [ -d "$base_path/$1" ]; then
		cd "$base_path/$1"
	else
		cd "$base_path"
	fi
}

# Tab completion for html: the project folders under the web root.
_html() {
	local base
	base=$(_html_base) || return 1
	_files -W "$base" -/
}
compdef _html html

# Porta nei dotfiles le impostazioni di noctalia cambiate dall'interfaccia:
# la shell scrive in ~/.local/state/noctalia/settings.toml, che non e' nel repo.
alias noctalia-sync="$DOTFILES_SCRIPTS/noctalia-sync"
alias accent-sync="$DOTFILES_SCRIPTS/accent-sync"
alias pa="php artisan"
