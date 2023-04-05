#!/bin/zsh

EM_WORK_DIR_NAME=${EM_WORK_DIR_NAME:=work}

function _em_print_help() {
	cat << EOF
em - Experiment-Manager

Usage:
	em init <project-name>
	em cd <branch-name>
	em new [-c] <base-branch-name> <new-branch-name>
	em checkout <branch-name>

Commands:
	init: create a new project
	cd: cd into a checked-out branch
	checkout: create a work tree and cd into branch
	new: fork from base branch, use -c option cd into its worktree

EOF

}


function _em_die() {
	echo "$1"

	_em_print_help
}


_EM_NEW_PWD=$PWD


function _em() {
	if [[ $# -eq 0 ]]; then
		_em_print_help
		return 0
	fi

	command=$1
	shift
	case "$command" in
		init) ;;
		cd|checkout|new|push|delete) _em_is_git_project || return 1 ;;
		*) _em_die "Unknown command '$command'"; return 1 ;;
	esac

	_EM_NEW_PWD=$PWD

	"_em_cmd_$command" "$@"
	[[ ${_EM_NEW_PWD} != ${PWD} ]] && cd ${_EM_NEW_PWD}
}

function __vgit() {
	echo "git $@"
	git $@
	return $?
}

function _em_is_git_project() {
	git rev-parse || return 1
	return 0
}


function _em_project_root() {
	local gitdir=$(git rev-parse --git-dir)
	gitdir=`realpath $gitdir`
	while true; do
		local name=$(basename $gitdir)
		if [[ $name == ".git" && -d $gitdir ]]; then
			break
		fi
		gitdir=$(dirname $gitdir)
	done
	local proj_root=$(dirname $gitdir)
	echo $proj_root
}


function _em_cmd_init() {
	if [[ $# -eq 0 ]]; then
		_em_die "Insufficient arguments."
		return
	else
		local reponame=$1
	fi

	mkdir $reponame
	cd $reponame

	__vgit init
	touch .gitignore
	__vgit add .gitignore
	__vgit commit -am "Initialze empty repo"
	__vgit branch empty
	mkdir ${EM_WORK_DIR_NAME}
	echo "/${EM_WORK_DIR_NAME}" > .gitignore
	__vgit commit -a --amend -m "Initialze master repo"
}


function _em_cmd_cd() {
	if [[ $# -eq 0 ]]; then
		_em_die "Insufficient arguments."
		return
	else
		local branch=$1
	fi

	git worktree list | grep '\['"${branch}"'\]$' >/dev/null || {
		echo "branch ${branch} is not checked out yet."
		return
	}

	while read -r -A tokens; do
		local worktree=${tokens[1]}
		local cur_branch=${tokens[3]}

		if [[ $cur_branch == "[${branch}]" ]]; then
			echo $worktree
			_EM_NEW_PWD=$worktree
			break
		fi
	done  < <(git worktree list)
}

function _em_cmd_checkout() {
	local branch=$1
	local local_branch has_branch=0 checked_out=0
	[[ -z $branch ]] && {
		_em_die "You must provide <branch-name>"
		return 1
	}

	if [[ $branch == "remotes/"* ]]; then
		local_branch=${branch#*/*/}
	else
		local_branch=${branch}
	fi

	git worktree list | grep '\['"${local_branch}"'\]$' >/dev/null && checked_out=1
	# already checked out
	if [[ $checked_out -eq 1 ]]; then
		echo "[${local_branch}] already checked out"
		_em_cmd_cd $local_branch
		return
	fi

	local work_tree_dir="`_em_project_root`/${EM_WORK_DIR_NAME}/${local_branch}"
	git rev-parse --quiet --verify $local_branch >/dev/null && has_branch=1
	if [[ $has_branch == 1 ]]; then
		__vgit worktree add $work_tree_dir $local_branch || return 1
	else
		# if local branch does not exist, create it
		__vgit worktree add $work_tree_dir -b $local_branch $branch || return 1
	fi
	_EM_NEW_PWD=$work_tree_dir
}

function _em_cmd_push() {
	local branch="`git rev-parse --abbrev-ref HEAD`"
	local remote=$1
	[[ -z $remote ]] && remote="origin"
	__vgit push -u $remote $branch
}


function _em_cmd_new() {
	local to_checkout="0"
	while getopts ":c" opt; do
		[[ $opt == "c" ]] && to_checkout="1"
	done

	shift $((OPTIND-1))

	local base_branch=$1
	local new_branch=$2

	[[ -z $base_branch || -z $new_branch ]] && {
		echo "You must provide <base-branch-name> <base-branch-name>"
		return 1
	}

	__vgit branch $new_branch $base_branch || return 1

	[[ $to_checkout == "1" ]] && _em_cmd_checkout $new_branch || {
		echo "new branch: $new_branch"
		echo "run 'em checkout $new_branch' if you want to check it out"
	}
}

function _em_cmd_delete() {

	local branch=$1 checked_out=0 has_branch=0

	[[ $branch == "master" || $branch == "empty" ]] && {
		echo "cannot delete master"
		return 1
	}

	[[ -z $branch ]] && {
		echo "Usage: em delete <branch-name>"
		return 1
	}

	git rev-parse --quiet --verify $branch >/dev/null && has_branch=1

	[[ $has_branch -eq 0 ]] && {
		echo "no local branch: $branch"
		return 1
	}

	local root_dir="`_em_project_root`"
	local work_tree_dir="${root_dir}/${EM_WORK_DIR_NAME}/${branch}"

	if [[ $PWD == $work_tree_dir ]]; then
		cd $root_dir
		_EM_NEW_PWD=$root_dir
	fi

	git worktree list | grep '\['"${branch}"'\]$' >/dev/null && checked_out=1
	# already checked out
	if [[ $checked_out -eq 1 ]]; then
		rm -rf $work_tree_dir
		__vgit worktree prune
	fi

	__vgit branch -D $branch

	echo "branch $branch has been deleted"

}


function _em_git_branches() {
	git branch --format='%(refname:lstrip=2)'  # local branches
	git branch -r --format='%(refname:lstrip=1)'  # local branches
}

function _em_git_local_branches() {
	git branch --format='%(refname:lstrip=2)'  # local branches
}


_em_fzfcmd() {
  [[ ${FZF_TMUX:-1} -eq 1 ]] &&
    echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf --border "
}

function _em_fzf_select_branch() {
	local PROMPT=${1:-select branch}
	_em_git_branches | $(_em_fzfcmd) +m --prompt "${PROMPT}> " +s
}

function _em_fzf_select_local_branch() {
	local PROMPT=${1:-select branch}
	_em_git_local_branches | $(_em_fzfcmd) +m --prompt "${PROMPT}> " +s
}


# zsh completion
__em_zsh_comdef() {

	local -a commands=(
	  init:"create new project"
		cd:"cd into a checked-out branch"
		checkout:"create a work tree and cd into branch"
		new:"fork from base branch, use -c option cd into its worktree"
		push:"push current branch to remote repo"
		delete:"delete a local branch"
	)

	_arguments \
		"1: :{_describe 'command' commands}" \
		'*:: :->args'

	case $state in
		args)
			__em_complete_branches() {
				local branches
				declare -a branches
				branches=($(_em_git_branches))
				for b in $branches; do
					compadd $b
				done
			}

			__em_complete_local_branches() {
				local branches
				declare -a branches
				branches=($(_em_git_local_branches))
				for b in $branches; do
					compadd $b
				done
			}

			case ${words[1]} in
				cd)
					_arguments '*:branch:__em_complete_local_branches'
					;;
				checkout|new|delete)
					_arguments '*:branch:__em_complete_branches'
					;;
			esac
			;;
		esac
}

compdef __em_zsh_comdef _em

# completion with fzf
fzf-em-completion() {
	() {
		local tokens cmd subcmd branch
		setopt localoptions noshwordsplit noksh_arrays

		tokens=(${(z)LBUFFER})
		if [[ ${#tokens} -lt 2 ]]; then
			zle fzf-completion
			return
		fi

		cmd=${tokens[1]}
		subcmd=${tokens[2]}

		if [[ $cmd == "em" && ${LBUFFER[-1]} == ' ' ]]; then
			case $subcmd in
				cd)
					branch=$(_em_fzf_select_local_branch)
					;;
				delete)
					branch=$(_em_fzf_select_local_branch)
					;;
				checkout)
					branch=$(_em_fzf_select_branch)
					;;
				new)
					local _n_words=${#tokens}
					[[ ${tokens[3]} == "-c" ]] && _n_words=$((_n_words-1))

					[[ ${_n_words} -eq 2 ]] && {
						branch=$(_em_fzf_select_branch "select base branch")
					} || zle expand-or-complete
					;;
			esac

			if [[ -n $branch ]]; then
				LBUFFER="$LBUFFER$branch"
			fi
			zle redisplay
			typeset -f zle-line-init >/dev/null && zle zle-line-init
		# Fall back to default fzf completion
		else
			zle fzf-completion
		fi
	}
}

which fzf &>/dev/null && {
	zle -N fzf-em-completion
	bindkey '^I' fzf-em-completion
}

alias em=_em
compdef __em_zsh_comdef em

# vim: ts=2 sts=2 sw=2 noexpandtab
