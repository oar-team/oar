# If not running interactively, don't do anything
[ -z "$PS1" ] && return

if [ "`id -u`" -eq 0 ]; then
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
else
  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
fi
export PATH

# simple history browsing
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend
bind '"\e[A"':history-search-backward
bind '"\e[B"':history-search-forward

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
    ;;
*)
    ;;
esac

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set variable to show git branch when in a git repository
# source: https://github.com/jimeh/git-aware-prompt/blob/master/prompt.sh
# added highlighting of repo part in path
function find_git_branch {
    git_subpath='/'
    local dir=${PWD} head
    until [ "$dir" = "" ]; do
        if [ -f "$dir/.git/HEAD" ]; then
            head=$(< "$dir/.git/HEAD")
            if [[ $head == ref:\ refs/heads/* ]]; then
                git_branch=" (${head#*/*/})"
            elif [[ $head != '' ]]; then
                git_describe=$(git describe --always)
                git_branch=" (detached: $git_describe)"
            else
                git_branch=' (unknown)'
	        fi
	        prompt_dir="${dir/$HOME/~}"
            return
        fi
        git_subpath="/${dir##*/}$git_subpath"
        dir="${dir%/*}"
    done
    git_branch=''
    prompt_dir="${PWD/$HOME/~}"
    git_subpath=''
}
function find_git_dirty {
    st=$(git status -s 2>/dev/null | tail -n 1)
    if [[ $st == "" ]]; then
        git_dirty=''
    else
        git_dirty='*'
    fi
}
PROMPT_COMMAND="find_git_branch; find_git_dirty; $PROMPT_COMMAND"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]: \[\e[1;37m\]$prompt_dir\[\e[1;36m\]$git_subpath\[\e[0;31m\]$git_branch\[\e[1;33m\]$git_dirty\[\033[01;34m\] \$\[\033[00m\] '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h: $prompt_dir$git_subpath$git_branch$git_dirty \$ '
fi

#if [ "$PS1" ]; then
#  if [ "$BASH" ]; then
#    PS1='\e[1;31m\u\e[1;34m@\e[1;33m\h\e[1;37m:\w\e[1;32m \$ \e[0;37m'
#  else
#    if [ "`id -u`" -eq 0 ]; then
#      PS1='# '
#    else
#      PS1='$ '
#    fi
#  fi
#fi


## aliases

# for fast typing
alias h='history'
alias g='git status'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -Ah'

# for human readable output
alias ls='ls -h'
alias df='df -h'
alias du='du -h'

# include local aliases if available
if [ -f ~/.localaliases ]; then
    . ~/.localaliases
fi

# colors
if [ -x /usr/bin/dircolors ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias ls='ls -G'
fi

export PATH=/opt/local/bin:/opt/local/sbin:$PATH
