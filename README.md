[![Build Status](https://travis-ci.org/ickc/bupc-install.svg?branch=master)](https://travis-ci.org/ickc/bupc-install)

# Description

This is a starter script to install [Berkeley UPC](http://upc.lbl.gov/download/). It uses the simplest configurations. macOS and Linux platforms are supported.

# Usage

```bash
./bupc-install.sh -h
```

To install the BUPC translator locally, use

```bash
./bupc-install.sh -l
```

Note that the default path for the bin is `$HOME/.upcc` such that `sudo` is not needed. You can specify your own by,

```bash
sudo ./bupc-install.sh -o /usr/local/berkeley_upc
```

# Download Binaries

You can also download the compiled binaries in [Releases · ickc/bupc-install](https://github.com/ickc/bupc-install/releases). It is experimental. To use it, decompress and compile your programs with UPCC pointing to `bin/upcc_multi`. For example,

```bash
make UPCC=$binaryPath/bin/upcc_multi ...
```

You make add that into your `PATH`, and symlink `upcc` to `upcc_multi`.

# License

Following BUPC, BSD license is used. Specifically, the 3-Clause BSD License.
