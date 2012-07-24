#!/bin/bash

umask 077

PREFIX="$HOME/.password-store"
ID="$PREFIX/.gpg-id"
GIT="$PREFIX/.git"

export GIT_DIR="$GIT"
export GIT_WORK_TREE="$PREFIX"

usage() {
	cat <<_EOF
Password Store
by Jason Donenfeld
   Jason@zx2c4.com

Usage:
    $0 --init gpg-id
        Initialize new password storage and use gpg-id for encryption.
    $0 [--ls]
        List passwords.
    $0 pass-name
        Show existing password.
    $0 --insert [--multiline] pass-name
        Insert new optionally multiline password.
    $0 --generate [--no-symbols] pass-name pass-length
        Generate a new password of pass-length with optionally no symbols.
    $0 --remove pass-name
        Remove existing password.
    $0 --push
        If the password store is a git repository, push the latest changes.
    $0 --pull
        If the password store is a git repository, pull the latest changes.
    $0 --help
        Show this text.
_EOF
}

if [[ $1 == "--init" ]]; then
	if [[ $# -ne 2 ]]; then
		echo "Usage: $0 $1 gpg-id"
		exit 1
	fi
	mkdir -v -p "$PREFIX"
	echo "$2" > "$ID"
	echo "Password store initialized for $2."
	exit 0
elif [[ $1 == "--help" ]]; then
	usage
	exit 0
fi

if ! [[ -f $ID ]]; then
	echo "You must run:"
	echo "    $0 --init your-gpg-id"
	echo "before you may use the password store."
	echo
	usage
	exit 1
else
	ID="$(head -n 1 "$ID")"
fi

if [[ $# -eq 0 ]] || [[ $1 == "--ls" ]]; then
	tree "$PREFIX" | tail -n +2 | head -n -2 | sed 's/\(.*\)\.gpg$/\1/';
elif [[ $1 == "--insert" ]]; then
	if [[ $# -lt 2 ]]; then
		echo "Usage: $0 $1 [--multiline] pass-name"
		exit 1
	fi
	ml=0
	if [[ $2 == "--multiline" ]]; then
		shift
		ml=1
	fi
	mkdir -p -v "$PREFIX/$(dirname "$2")"

	passfile="$PREFIX/$2.gpg"
	if [[ $ml -eq 0 ]]; then
		echo -n "Enter password for $2: "
		head -n 1 | gpg -e -r "$ID" > "$passfile"
	else
		echo "Enter contents of $2 and press Ctrl+D when finished:"
		echo
		cat | gpg -e -r "$ID" > "$passfile"
	fi
	if [[ -d $GIT ]]; then
		git add "$passfile"
		git commit -m "Added given password for $2 to store."
	fi
elif [[ $1 == "--generate" ]]; then
	if [[ $# -lt 3 ]]; then
		echo "Usage: $0 $1 [--no-symbols] pass-name pass-length"
		exit 1
	fi
	symbols="-y"
	if [[ $2 == "--no-symbols" ]]; then
		symbols=""
		shift
	fi
	if ! [[ $3 =~ ^[0-9]+$ ]]; then
		echo "pass-length \"$3\" must be a number."
		exit 1
	fi
	mkdir -p -v "$PREFIX/$(dirname "$2")"
	pass="$(pwgen -s $symbols $3 1)"
	passfile="$PREFIX/$2.gpg"
	echo $pass | gpg -e -r "$ID" > "$passfile"
	if [[ -d $GIT ]]; then
		git add "$passfile"
		git commit -m "Added generated password for $2 to store."
	fi
	echo "The generated password to $2 is:"
	echo "$pass"
elif [[ $1 == "--remove" ]]; then
	if [[ $# -ne 2 ]]; then
		echo "Usage: $0 $1 pass-name"
		exit
	fi
	passfile="$PREFIX/$2.gpg"
	if ! [[ -f $passfile ]]; then
		echo "$2 is not in the password store."
		exit 1
	fi
	rm -i -v "$passfile"
	if [[ -d $GIT ]] && ! [[ -f "$passfile" ]]; then
		git rm -f "$passfile"
		git commit -m "Removed $2 from store."
	fi
elif [[ $1 == "--push" ]]; then
	if [[ -d $GIT ]]; then
		shift
		exec git push $@
	else
		echo "Error: the password store is not a git repository."
		exit 1
	fi
elif [[ $1 == "--pull" ]]; then
	if [[ -d $GIT ]]; then
		shift
		exec git pull $@
	else
		echo "Error: the password store is not a git repository."
		exit 1
	fi
elif [[ $# -eq 1 ]]; then
	passfile="$PREFIX/$1.gpg"
	if ! [[ -f $passfile ]]; then
		echo "$1 is not in the password store."
		exit 1
	fi
	exec gpg -q -d "$passfile"
else
	usage
	exit 1
fi