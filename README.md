
# ExpMan

🍽️ ExpMan is a handy experiment management tool based on [git-worktree](https://git-scm.com/docs/git-worktree). 

## Key features

- 🔱 Work on multiple git branches in parallel
- 🛠️ A set of commands to easily create, fork, checkout and push branches
- 🚀 Integration with [fzf][fzf], find target in 1 second and jump among 1000+ branches 

## Why ExpMan?

In machine learning and other experimental sciences, engineers often need to run multiple experiments simultaneously in order to efficiently search for parameters and validate hypotheses.
Using Git branches to manage experiments can be very helpful for code comparison and quickly jumping between experiments. 
However, simple usage of the `git-branch` and `git-checkout` commands can only allow working on a single branch at a time. 
Git-worktree is a great solution for working on multiple branches simultaneously, but with the number of experiments 📈 potentially reaching into the hundreds or thousands in a short period of time, 🤯 engineers can easily lost themselves.

ExpMan provides a set of handy commands that not only allows beginners to quickly master parallel operations on multiple branches, but also integrates the incredibly useful [fzf][fzf] for fuzzy searching 🔎 among thousands of branches, enabling engineers to quickly find their desired experiments and significantly improving their efficiency in scientific research.

## Installation

**Currently Only Zsh is supported**

1. Install [fzf][fzf]
2. Download
```bash
git clone https://github.com/megvii-research/expman $HOME/.expman
```
3. Load expman by adding one line in `~/.zshrc`
```bash
echo '[[ -o interactive ]] && source $HOME/.expman/expman.zsh' >> ~/.zshrc
```

## Get Started

### 🏗️ Create a new repository
```bash
# create project
em init <project-name>
# go to project
cd <project-name>
```

### 🧪 Create an empty experiment
```bash
# create an experiment, but stay at where you were
em new empty <my-experiment-name> 
# create an experiment, and go to the new experiment dir
em new -c empty <my-experiment-name>
```

### 🚘 Goto some experiment
```bash
em cd <experiment-name>
```

### 🖖 Fork existing branch to new
```bash
# create an experiment, but stay at where you were
em new <old-experiment> <new-experiment> 
# create an experiment, and go to the new experiment dir
em new -c <old-experiment> <new-experiment>
```

### 📥 Checkout a branch
If you clone a repository at a new location, or you have co-workers pushed their experiments to remote

```bash
git fetch  # sync with remote
em checkout remotes/origin/<experiment-name>
```

### 📤  Push to remote
```bash
em push <experiment-name>
```

### 🗑️ Delete a local branch
```bash
em delete <experiment-name>
```

**Note**: Only local branch is deleted, to delete a remote branch, use native git comand, or simply use your git-web UI like github.

```bash
git push <remote> :<branch-name>
```

### 👀 Integrate with `fzf`

Press `<TAB>` following `em` commands, and magic happens.

```bash
em new # press <TAB> 
em cd # press <TAB>
em checkout # press <TAB>
```

## LICENSE

Apache License 2.0

[fzf]: https://github.com/junegunn/fzf
