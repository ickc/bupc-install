#!/usr/bin/env bash

# default version, will be overridden by cli option
version="2.24.2"

usage="./$(basename "$0") [-h] [-o outdir] [-v version] [-l local] [-c CC] [-p CXX] --- install Berkeley UPC

where:
	-h	show this help message
	-o	set the output directory. Default: \$HOME/.upcc
	-v	the version of the Berkeley UPC that you want to install. Default: %s
	-l	build the translator locally instead of the default HTTP-based Berkeley UPC-to-C (BUPC) translator.
	-c	CC. Default: cc
	-p	CXX. Default: c++

Note: Default URLs are:

	BUPC source code	http://upc.lbl.gov/download/release/berkeley_upc-%s.tar.gz
	Translator source code	http://upc.lbl.gov/download/release/berkeley_upc_translator-%s.tar.gz
	HTTP Translator URL	http://upc-translator.lbl.gov/upcc-%s.cgi
"

# Helper functions #############################################################

gnumake() {
	if hash gmake 2>/dev/null; then
		gmake "$@"
	else
		make "$@"
	fi
}

mkdirerr() {
	mkdir -p "$@"
	if [[ $? -eq 0 ]]; then
		printf "Successfully created %s\n" "$@"
	else
		printf "Could not create %s\n" "$@" >&2
		exit 1
	fi
}

download() {
	filename="${@##*/}"
	if [[ ! -f "$filename" ]]; then
		curl "$@" -O .
		if [[ ! -f "$filename" ]]; then
			printf "Cannot download %s from %s\n" "$filename" "$@" >&2
			exit 1
		fi
	else
		printf "%s already exist. Use the existing %s instead.\n" "$filename" "$filename"
	fi
}

decompress() {
	folderName="${@%.tar.gz}"
	if [[ ! -d "$folderName" ]]; then
		tar -xzf "$@"
	else
		printf "%s already existed. To remove it, run\nrm -r %s\nUse the existing %s instead.\n" "$folderName" "$tempdir/$folderName" "$folderName"
	fi
}

# getopts ######################################################################

# reset getopts
OPTIND=1

# Initialize parameters
outdir="$HOME/.upcc"
CC="cc"
CXX="c++"

# get the options
while getopts "o:v:lc:p:h" opt; do
	case "$opt" in
	o)	outdir="$OPTARG"
		;;
	v)	version="$OPTARG"
		;;
	l)	local=true
		;;
	c)	CC="$OPTARG"
		;;
	p)	CXX="$OPTARG"
		;;
	h)	printf "$usage" "$version" "$version" "$version" "$version"
		exit 0
		;;
	*)	printf "$usage" "$version" "$version" "$version" "$version"
		exit 1
		;;
	esac
done

urlBUPC="http://upc.lbl.gov/download/release/berkeley_upc-$version.tar.gz"
urlTranslator="http://upc.lbl.gov/download/release/berkeley_upc_translator-$version.tar.gz"

# get the filenameBUPC from the urlBUPC
filenameBUPC="${urlBUPC##*/}"
folderNameBUPC="${filenameBUPC%.tar.gz}"
# get the filenameBUPC from the urlTranslator
filenameTranslator="${urlTranslator##*/}"
folderNameTranslator="${filenameTranslator%.tar.gz}"

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

if [[ $DEBUG ]]; then
	printf "%s\n" \
		"$outdir" \
		"$urlBUPC" \
		"$local" \
		"$urlTranslator" \
		"$CC" \
		"$CXX" \
		"$filenameBUPC" \
		"$folderNameBUPC" \
		"$filenameTranslator" \
		"$folderNameTranslator" \
		"$tempdir" \
		"$bupcdir" \
		"$bupcbin" \
		"$bupcman" \
		"$translatordir"
fi

# Download #####################################################################

# create out-dir
if [[ -d "$outdir" ]]; then
	printf "%s already existed. Contents will be overwritten.\n\
You may want to run\n\
rm -r %s\n\
to clear this folder if the installation fails.\n" "$outdir" "$outdir"
fi
mkdirerr "$tempdir"
# BUPC
mkdirerr "$bupcdir"
# Translator
if [[ ! -z "$local" ]]; then
	mkdirerr "$translatordir"
fi

# from now on we're in $tempdir
cd "$tempdir"

# download bupc
download "$urlBUPC"
# decompress
decompress "$filenameBUPC"

# download translator
if [[ ! -z "$local" ]]; then
	download "$urlTranslator"
	decompress "$filenameTranslator"
fi

# Compile ######################################################################

# Translator
if [[ ! -z "$local" ]]; then
	# from now on we're in $folderNameTranslator
	cd "$folderNameTranslator"
	gnumake CC=$CC CXX=$CXX && gnumake install -j PREFIX="$translatordir" CC=$CC CXX=$CXX
	if [[ $? -eq 0 ]]; then
		printf "BUPC Translator build suceeded.\n"
	else
		printf "BUPC Translator build failed.\n" >&2
		exit 1
	fi
fi

# BUPC
# from now on we're in folderNameBUPC
cd "$tempdir/$folderNameBUPC"
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
