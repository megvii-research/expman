#!/bin/zsh

EM_WORK_DIR_NAME=${EM_WORK_DIR_NAME:=work}  # readonly default work directory name
_EM_WORKDIR_CONFIG_KEY="expman.workdir.path"
_EM_WORKDIR_ABSOLUTE_CONFIG_KEY="expman.workdir.absolute"

function _em_print_help() {
	cat << EOF
em - Experiment-Manager

Usage:
	em init <project-name>
	em cd <branch-name>
	em new [-c] <base-branch-name> <new-branch-name>
	em checkout <branch-name>
	em delete <branch-name>

Commands:
	init: create a new project
	cd: cd into a checked-out branch
	checkout: create a work tree and cd into branch
	new: fork from base branch, use -c option cd into its worktree
	delete: delelete a local branch
	push: push a local branch to remote

EOF
}

function _em_die() {
	echo "$1"

	_em_print_help
}



function _em_get_work_dir() {
  local root="`_em_project_root`"

  if [[ "$(git config --get ${_EM_WORKDIR_ABSOLUTE_CONFIG_KEY} 2>/dev/null)" == "true" ]]; then
    echo "$(git config --get ${_EM_WORKDIR_CONFIG_KEY})"
  else
    local work_dir="${root}/$(git config --get ${_EM_WORKDIR_CONFIG_KEY} 2>/dev/null || echo "$EM_WORK_DIR_NAME")"
		echo $(realpath "$work_dir")
  fi
}


function _em_add_to_gitignore() {
  local root="`_em_project_root`"
  local work_dir="$(_em_get_work_dir)"

	# Use realpath to resolve any symlinks and get absolute paths
	root=$(realpath "$root")
	work_dir=$(realpath "$work_dir")

  # If work_dir is outside of project root, no need to add to .gitignore
  if [[ "$work_dir" != "$root"* ]]; then
    return 0
  fi

  # Calculate relative path from root to work_dir
  local rel_path="${work_dir#$root/}"
  rel_path="${rel_path%/}"

  # Anchor the path at root with leading slash
  pattern="/${rel_path}"

  if [[ -f "${root}/.gitignore" ]]; then
    grep -q "^${pattern}" "${root}/.gitignore" 2>/dev/null || echo "$pattern" >> "${root}/.gitignore"
  else
    echo "$pattern" > "${root}/.gitignore"
  fi
}

function _em_ensure_work_dir() {
  local root="`_em_project_root`"
  local work_dir_name

  work_dir_name="$(git config --get ${_EM_WORKDIR_CONFIG_KEY} 2>/dev/null)"
  if [[ -n "$work_dir_name" ]]; then
    return 0
  fi

  local is_em_project=0
	[[ -d "${root}/${EM_WORK_DIR_NAME}" ]] && is_em_project=1

  echo "First time using em. Work directory needs to be configured."
  echo ""

  local repo_name=$(basename "$root")
  local work_dir_parent_abs="${root}/../${repo_name}.worktrees"
	work_dir_parent_abs=$(realpath "$work_dir_parent_abs")

  if [[ $is_em_project -eq 1 ]]; then
    local work_dir_rel="${WORK_DIR_NAME}"
    local work_dir_abs="${root}/${work_dir_rel}"

    echo "Select worktrees location:"
    echo "1) Inside project: ${work_dir_rel}/"
    [[ -d "$work_dir_abs" ]] && echo "   ✓ Directory exists" || echo "   - Will create: $work_dir_abs"

    echo "2) Outside project: ../${repo_name}.worktrees/"
    [[ -d "$work_dir_parent_abs" ]] && echo "   ✓ Directory exists" || echo "   - Will create: $work_dir_parent_abs"

    echo "3) Custom path"
    echo ""

    local choice
    vared -p "Choose [1-3]: " choice

    case "$choice" in
      1)
        work_dir_name="$work_dir_rel"
        ;;
      2)
        work_dir_name="../${repo_name}.worktrees"
        ;;
      3)
        vared -p "Enter path: " work_dir_name
        [[ -z "$work_dir_name" ]] && {
          echo "Path cannot be empty"
          return 1
        }
        ;;
      *)
        echo "Invalid choice"
        return 1
        ;;
    esac
  else
    echo "Select worktrees location:"
    echo "1) Outside project: ../${repo_name}.worktrees/"
    [[ -d "$work_dir_parent_abs" ]] && echo "   ✓ Directory exists" || echo "   - Will create: $work_dir_parent_abs"

    echo "2) Custom path"
    echo ""

    local choice
    vared -p "Choose [1-2]: " choice

    case "$choice" in
      1)
        work_dir_name="${work_dir_parent_abs}"
        ;;
      2)
        vared -p "Enter path: " work_dir_name
        [[ -z "$work_dir_name" ]] && {
          echo "Path cannot be empty"
          return 1
        }
				work_dir_name=$(realpath "$work_dir_name")
        ;;
      *)
        echo "Invalid choice"
        return 1
        ;;
    esac
  fi

  if [[ "$work_dir_name" == /* ]]; then
    git config ${_EM_WORKDIR_ABSOLUTE_CONFIG_KEY} "true"
  else
    git config ${_EM_WORKDIR_ABSOLUTE_CONFIG_KEY} "false"
  fi

  git config ${_EM_WORKDIR_CONFIG_KEY} "$work_dir_name"

  local work_dir="$(_em_get_work_dir)"
  if [[ ! -d "$work_dir" ]]; then
    echo "Creating directory: $work_dir"
    mkdir -p "$work_dir"
  fi

	_em_add_to_gitignore

  echo "Configuration saved!"
  return 0
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
	__vgit commit -am "Initialize empty repo"
	__vgit branch empty
	mkdir ${EM_WORK_DIR_NAME}
	echo "/${EM_WORK_DIR_NAME}" > .gitignore

	# Save work directory configuration
	git config ${_EM_WORKDIR_CONFIG_KEY} "${EM_WORK_DIR_NAME}"
	git config ${_EM_WORKDIR_ABSOLUTE_CONFIG_KEY} "false"

	__vgit commit -a --amend -m "Initialize master repo"
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
	_em_ensure_work_dir || return 1

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

	local work_tree_dir="$(_em_get_work_dir)/${local_branch}"
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
	_em_ensure_work_dir || return 1

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

	[[ $to_checkout == "1" ]] && {
		_em_cmd_checkout $new_branch
	} || {
		echo "new branch: $new_branch"
		echo "run 'em checkout $new_branch' if you want to check it out"
	}
}

function _em_cmd_delete() {
	_em_ensure_work_dir || return 1

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
	local work_tree_dir="$(_em_get_work_dir)/${branch}"

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
