#!/usr/bin/env bash

usage="./$(basename "$0") [-h] [-o outdir] [-u url-BPUC] [-l local] [-U url-translator] [-c CC] [-p CXX] -- install Berkeley UPC

where:
	-h	show this help message
	-o	set the output directory. Default: \$HOME/.upcc
	-u	URL to the source code of BUPC. Default: http://upc.lbl.gov/download/release/berkeley_upc-2.24.2.tar.gz
	-l	build the translator locally instead of the default HTTP-based Berkeley UPC-to-C (BUPC) translator.
	-U	URL to the source code of BUPC-translator. Default: http://upc.lbl.gov/download/release/berkeley_upc_translator-2.24.2.tar.gz
	-c	CC. Default: cc
	-p	CXX. Default: c++"

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
		printf "%s already existed. To remove it, run\nrm -r %s\n" "$folderName" "$tempdir/$folderName" >&2
		exit 1
	fi
}

# getopts ######################################################################

# reset getopts
OPTIND=1

# Initialize parameters
outdir="$HOME/.upcc"
urlBUPC="http://upc.lbl.gov/download/release/berkeley_upc-2.24.0.tar.gz"
urlTranslator="http://upc.lbl.gov/download/release/berkeley_upc_translator-2.24.0.tar.gz"
CC="cc"
CXX="c++"

# get the options
while getopts "o:u:lU:c:p:h" opt; do
	case "$opt" in
	o)	outdir="$OPTARG"
		;;
	u)	urlBUPC="$OPTARG"
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
	gnumake && gnumake install -j PREFIX="$translatordir"
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
