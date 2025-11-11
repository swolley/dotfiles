# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME=""

# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

plugins=(sudo git archlinux zsh-autosuggestions zsh-syntax-highlighting copyfile)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
   export EDITOR='nvim'
# fi

# For a full list of active aliases, run `alias`.

source ~/.zshrc_customs.zsh

export PATH=$HOME/.local/bin:$PATH

# Initialize Starship prompt
eval "$(starship init zsh)"

# Auto-start tmux if not already inside tmux and close it when exiting
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
    # Verifica che la directory corrente esista, altrimenti usa la home
    if [ ! -d "$PWD" ]; then
        cd ~
    fi
    
    # Use shared "default" session
    # All terminals attach to the same session, so you can reattach to a closed session
    # Standard tmux behavior: all terminals see the same active window
    if tmux has-session -t default 2>/dev/null; then
        # Session already exists
        # Check if current directory is different from the active window's directory
        # If different, probably opened from Nautilus - create a new window
        # Otherwise, attach to the last active window (normal terminal)
        ACTIVE_WINDOW_DIR=$(tmux display-message -t default -p '#{pane_current_path}' 2>/dev/null)
        if [ -n "$ACTIVE_WINDOW_DIR" ] && [ "$PWD" != "$ACTIVE_WINDOW_DIR" ]; then
            # Different directory from active window: create a new window (probably from Nautilus)
            NEW_WINDOW=$(tmux new-window -t default -c "$PWD" -P -F '#{window_index}' 2>/dev/null)
            if [ -n "$NEW_WINDOW" ]; then
                # Attach to the specific window we just created (in the current directory)
                exec tmux attach-session -t default \; select-window -t "$NEW_WINDOW"
            else
                # Fallback: attach to the session
                exec tmux attach-session -t default
            fi
        else
            # Same directory as active window: attach to the last active window (normal terminal)
            exec tmux attach-session -t default
        fi
    else
        # Session does not exist: create a new session in the current directory
        exec tmux new-session -s default -c "$PWD"
    fi
fi
