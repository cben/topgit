#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

populate= # Set to 1 if we shall seed local branches with this
name=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--populate)
		populate=1;;
	-*)
		echo "Usage: tg [...] remote [--populate] [<remote>]" >&2
		exit 1;;
	*)
		name="$arg";;
	esac
done

[ -n "$name" ] ||
	name="$base_remote"

git config "remote.$name.url" >/dev/null || die "unknown remote '$name'"


## Configure the remote

git config --replace-all "remote.$name.fetch" "+refs/top-bases/*:refs/remotes/$name/top-bases/*" "\\+refs/top-bases/\\*:refs/remotes/$name/top-bases/\\*"

if git config --get-all "remote.$name.push" "\\+refs/top-bases/\\*:refs/top-bases/\\*" >/dev/null && test "xtrue" != "x$(git config --bool --get topgit.dontwarnonoldpushspecs)"; then
	info "Probably you want to remove the push specs introduced by an old version of topgit:"
	info '       git config --unset-all "remote.'$name'.push" "\\+refs/top-bases/\\*:refs/top-bases/\\*"'
	info '       git config --unset-all "remote.'$name'.push" "\\+refs/heads/\\*:refs/heads/\\*"'
	info '(or use git config --bool --add topgit.dontwarnonoldpushspecs true to get rid of this warning)'
fi

info "Remote $name can now follow TopGit topic branches."
if [ -z "$populate" ]; then
	info "Next, do: git fetch $name"
	exit
fi


## Populate local branches

info "Populating local topic branches from remote '$name'..."

## The order of refspecs is very important, because both heads and
## top-bases are mapped under the same namespace refs/remotes/$name.
## If we put the 2nd refspec before the 1st one, stale refs reverse
## lookup would fail and "refs/remotes/$name/top-bases/XX" reverse
## lookup as a non-exist "refs/heads/top-bases/XX", and would be
## deleted by accident.
git fetch --prune "$name" \
	"+refs/top-bases/*:refs/remotes/$name/top-bases/*" \
	"+refs/heads/*:refs/remotes/$name/*"

git for-each-ref "refs/remotes/$name/top-bases" |
	while read rev type ref; do
		branch="${ref#refs/remotes/$name/top-bases/}"
		if ! git rev-parse "refs/remotes/$name/$branch" >/dev/null 2>&1; then
			info "Skipping remote $name/top-bases/$branch that's missing its branch"
			continue
		fi
		if git rev-parse "$branch" >/dev/null 2>&1; then
			git rev-parse "refs/top-bases/$branch" >/dev/null 2>&1 ||
				git update-ref "refs/top-bases/$branch" "$rev"
			info "Skipping branch $branch: Already exists"
			continue
		fi
		info "Adding branch $branch..."
		git update-ref "refs/top-bases/$branch" "$rev"
		git update-ref "refs/heads/$branch" "$(git rev-parse "$name/$branch")"
	done

git config "topgit.remote" "$name"
info "The remote '$name' is now the default source of topic branches."

# vim:noet
