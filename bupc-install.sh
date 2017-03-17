#!/usr/bin/env bash

usage="./$(basename "$0") [-h] [-o outdir] [-u url] [-l local] [-U url-translator] [-c CC] [-p CXX] -- install Berkeley UPC

where:
	-h	show this help message
	-o	set the output directory. Default: \$HOME/.upcc
	-u	URL to the source code of BUPC. Default: http://upc.lbl.gov/download/release/berkeley_upc-2.24.0.tar.gz
	-l	build the translator locally instead of the default HTTP-based Berkeley UPC-to-C (BUPC) translator.
	-U	URL to the source code of BUPC-translator. Default: http://upc.lbl.gov/download/release/berkeley_upc_translator-2.24.0.tar.gz
	-c	CC. Default: cc
	-p	CXX. Default: c++"

# getopts ######################################################################

gnumake() {
	if hash gmake 2>/dev/null; then
		gmake "$@"
	else
		make "$@"
	fi
}

# reset getopts
OPTIND=1

# Initialize parameters
outdir="$HOME/.upcc"
url="http://upc.lbl.gov/download/release/berkeley_upc-2.24.0.tar.gz"
urlTranslator="http://upc.lbl.gov/download/release/berkeley_upc_translator-2.24.0.tar.gz"
CC="cc"
CXX="c++"

# get the options
while getopts "o:u:lU:c:p:h" opt; do
	case "$opt" in
	o)	outdir="$OPTARG"
		;;
	u)	url="$OPTARG"
		;;
	l)	local=true
		;;
	U)	urlTranslator="$OPTARG"
		;;
	c)	CC="$OPTARG"
		;;
	p)	CXX="$OPTARG"
		;;
	h)	printf "%s\n" "$usage"
		exit 0
		;;
	*)	printf "%s\n" "$usage"
		exit 1
		;;
	esac
done

# get the absolute path of outdir
outdir=$(realpath outdir)

# get the filename from the url
filename="${url##*/}"
folderName="${filename%.tar.gz}"

# get the filename from the translator url
filenameTranslator="${urlTranslator##*/}"
folderNameTranslator="${filenameTranslator%.tar.gz}"

if [[ $DEBUG ]]; then
	printf "%s\n" "$outdir" "$url" "$local" "$urlTranslator" "$CC" "$CXX" "$filename" "$folderName"
fi

# dirs within outdir
tempdir="$outdir/temp"
bupcdir="$outdir/bupc"
bupcbin="$bupcdir/bin"
bupcman="$bupcdir/man"
translatordir="$outdir/translator"

# warning message for translator without gmake
if [[ ! -z "$local" ]] && [[ $(uname) == "Darwin" ]]; then
	printf "%s\n" "Note that compiling the translator requires GNU make." "If the installation failed, install GNU make by" "brew install homebrew/dupes/make"
fi

# Download #####################################################################

# create out-dir
if [[ -d "$outdir" ]]; then
	printf "%s already existed. Contents will be overwritten.\n\
You may want to run\n\
rm -r %s\n\
to clear this folder if the installation fails.\n" "$outdir" "$outdir"
fi
mkdir -p "$tempdir"
if [[ $? -eq 0 ]]; then
	printf "Successfully created %s\n" "$tempdir"
else
	printf "Could not create %s\n" "$tempdir" >&2
	exit 1
fi
# BUPC
mkdir -p "$bupcdir"
if [[ $? -eq 0 ]]; then
	printf "Successfully created %s\n" "$bupcdir"
else
	printf "Could not create %s\n" "$bupcdir" >&2
	exit 1
fi
# Translator
if [[ ! -z "$local" ]]; then
	mkdir -p "$translatordir"
	if [[ $? -eq 0 ]]; then
		printf "Successfully created %s\n" "$translatordir"
	else
		printf "Could not create %s\n" "$translatordir" >&2
		exit 1
	fi
fi

# from now on we're in $tempdir
cd "$tempdir"

# download bupc
if [[ ! -f "$filename" ]]; then
	curl "$url" -O .
	if [[ ! -f "$filename" ]]; then
		printf "Cannot download %s from %s\n" "$filename" "$url" >&2
		exit 1
	fi
else
	printf "%s already exist. Use the existing %s instead.\n" "$filename" "$filename"
fi
# uncompress
if [[ ! -d "$folderName" ]]; then
	tar -xzf "$filename"
else
	printf "%s already existed. To remove it, run\nrm -r %s\n" "$folderName" "$(realpath "$folderName")" >&2
	exit 1
fi

# download translator
if [[ ! -z "$local" ]]; then
	if [[ ! -f "$filenameTranslator" ]]; then
		curl "$urlTranslator" -O .
		if [[ ! -f "$filenameTranslator" ]]; then
			printf "Cannot download %s from %s\n" "$filenameTranslator" "$urlTranslator" >&2
			exit 1
		fi
	else
		printf "%s already exist. Use the existing %s instead.\n" "$filenameTranslator" "$filenameTranslator"
	fi
	# uncompress
	if [[ ! -d "$folderNameTranslator" ]]; then
		tar -xzf "$filenameTranslator"
	else
		printf "%s already existed. To remove it, run\nrm -r %s\n" "$folderNameTranslator" "$(realpath "$folderNameTranslator")" >&2
		exit 1
	fi
fi

# Compile ######################################################################

# Translator
if [[ ! -z "$local" ]]; then
	# from now on we're in $folderNameTranslator
	cd "$folderNameTranslator"
	gnumake && gnumake install -j PREFIX="$translatordir"
	if [[ $? -eq 0 ]]; then
		printf "BUPC Translator build suceeded.\n"
	else
		printf "BUPC Translator build failed.\n" >&2
		exit 1
	fi
fi

# BUPC
# from now on we're in folderName
cd "$tempdir/$folderName"
if [[ ! -z "$local" ]]; then
	./configure CC=$CC CXX=$CXX --prefix="$bupcdir" BUPC_TRANS=$translatordir/targ
else
	./configure CC=$CC CXX=$CXX --prefix="$bupcdir"
fi
gnumake && gnumake install -j
if [[ $? -eq 0 ]]; then
	printf "BUPC build suceeded.\n"
else
	printf "BUPC build failed.\n" >&2
	exit 1
fi

# test #########################################################################

env UPCC_FLAGS= ./upcc --norc --version
if [[ $? -eq 0 ]]; then
	printf "BUPC test suceeded.\n"
else
	printf "BUPC test failed.\n" >&2
	exit 1
fi

# Add it to the PATH ###########################################################

if [[ $(uname) == "Darwin" ]]; then
	bashProfile=".bash_profile"
else
	bashProfile=".bashrc"
fi

if ! grep -qE "$bupcbin" $HOME/$bashProfile; then
	printf "%s\n" "" "# BUPC" 'export PATH="$PATH:'$bupcbin'"' >> $HOME/$bashProfile
else
	printf "Seems like %s is already in the \$PATH of %s. If not, please add it to the \$PATH manually.\n" "$bupcbin" "$HOME/$bashProfile"
fi

if ! grep -qE "$bupcman" $HOME/$bashProfile; then
	printf "%s\n" "" "# BUPC MAN" 'export MANPATH="$MANPATH:'$bupcman'"' >> $HOME/$bashProfile
else
	printf "Seems like %s is already in the \$MANPATH of %s. If not, please add it to the \$MANPATH manually.\n" "$bupcman" "$HOME/$bashProfile"
fi

# remove source code directory #################################################

if [[ ! $DEBUG ]]; then
	rm -rf "$tempdir"
fi
