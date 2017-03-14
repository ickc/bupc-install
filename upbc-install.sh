#!/usr/bin/env bash

usage="./$(basename "$0") [-h] [-o outdir] [-u url] [-c CC] [-p CXX] -- install Berkeley UPC

where:
	-h	show this help message
	-o	set the temporary output directory. Default: \$HOME/.upcc
	-u	URL to the source code of BUPC. Default: http://upc.lbl.gov/download/release/berkeley_upc-2.24.0.tar.gz
	-c	CC. Default: cc
	-p	CXX. Default: c++"

# getopts ######################################################################



# reset getopts
OPTIND=1

# Initialize parameters
outdir="$HOME/.upcc"
url="http://upc.lbl.gov/download/release/berkeley_upc-2.24.0.tar.gz"
CC="cc"
CXX="c++"
# default path for the bin from BUPC
binPath="/usr/local/berkeley_upc"

# get the options
while getopts "o:u:c:p:h" opt; do
	case "$opt" in
	o)	outdir="$OPTARG"
		;;
	u)	url="$OPTARG"
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

# get the filename from the url
filename="${url##*/}"
folderName="${filename%.tar.gz}"

if [[ $DEBUG ]]; then
	printf "%s\n" "$outdir" "$url" "$CC" "$CXX" "$filename" "$folderName"
fi

# Download #####################################################################

# create out-dir
if [[ ! -d "$outdir" ]]; then
	mkdir -p $outdir
	if [[ $? -eq 0 ]]; then
		printf "Successfully created %s\n" "$outdir"
	else
		printf "Could not create %s\n" "$outdir" >&2
		exit 1
	fi
else
	printf "%s already existed. Use this for the output directory.\n" "$outdir"
fi

# from now on we're in outdir
cd "$outdir"

# download
if [[ ! -f "$filename" ]]; then
	curl "$url" -O .
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

# Compile ######################################################################

# from now on we're in folderName
cd "$folderName"

./configure CC=$CC CXX=$CXX

make && make install -j
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

if ! grep -qE "$binPath" $HOME/$bashProfile; then
	printf "%s\n" "" "# BUPC" 'export PATH="$PATH:'$binPath'"' >> $HOME/$bashProfile
else
	printf "Seems like %s is already in the \$PATH of %s. If not, please add it to the \$PATH manually.\n" "$binPath" "$HOME/$bashProfile"
fi

# remove source code directory #################################################

if [[ ! $DEBUG ]]; then
	rm -rf "$outdir"
fi
