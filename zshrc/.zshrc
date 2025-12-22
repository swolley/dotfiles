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

# Java configuration
export JAVA_HOME=$(ls -d /usr/lib/jvm/java-* | sort -V | tail -n 1)
export PATH=$PATH:$JAVA_HOME/bin

# Initialize Starship prompt
eval "$(starship init zsh)"

# Auto-start tmux if not already inside tmux and close it when exiting
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
    # Verifica che la directory corrente esista, altrimenti usa la home
    if [ ! -d "$PWD" ]; then
        cd ~
    fi
    
    # Use shared "default" session
    # If session exists:
    #   - If opened from Nautilus (different directory): find or create window in that directory
    #   - If normal terminal (same directory): attach to existing session
    if tmux has-session -t default 2>/dev/null; then
        # Session already exists
        ACTIVE_WINDOW_DIR=$(tmux display-message -t default -p '#{pane_current_path}' 2>/dev/null)
        
        # Check if current directory is different from active window (probably opened from Nautilus)
        if [ -n "$ACTIVE_WINDOW_DIR" ] && [ "$PWD" != "$ACTIVE_WINDOW_DIR" ]; then
            # Different directory: try to find existing window in this directory
            EXISTING_WINDOW=""
            while IFS= read -r line; do
                window_index=$(echo "$line" | cut -d' ' -f1)
                window_path=$(echo "$line" | cut -d' ' -f2-)
                if [ "$window_path" = "$PWD" ]; then
                    EXISTING_WINDOW="$window_index"
                    break
                fi
            done < <(tmux list-windows -t default -F '#{window_index} #{pane_current_path}' 2>/dev/null)
            
            if [ -n "$EXISTING_WINDOW" ]; then
                # Found existing window in this directory: attach to it
                exec tmux attach-session -t default \; select-window -t "$EXISTING_WINDOW"
            else
                # No window in this directory: create a new one (opened from Nautilus)
                NEW_WINDOW=$(tmux new-window -t default -c "$PWD" -P -F '#{window_index}' 2>/dev/null)
                if [ -n "$NEW_WINDOW" ]; then
                    exec tmux attach-session -t default \; select-window -t "$NEW_WINDOW"
                else
                    exec tmux attach-session -t default
                fi
            fi
        else
            # Same directory as active window: normal terminal, just attach (no new windows)
            exec tmux attach-session -t default
        fi
    else
        # Session does not exist: create a new session in the current directory
        exec tmux new-session -s default -c "$PWD"
    fi
fi
