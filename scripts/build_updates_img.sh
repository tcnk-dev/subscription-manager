#!/bin/bash

# A script that wraps make install to create an updates.img suitable for anaconda.
# Note: This script must be run on Fedora 27 to produce an updates image suitable for Fedora 27
#       due to compatibility of binary modules.
PROJECT_ROOT=$(git rev-parse --show-toplevel)
UPDATE_DIR=$(mktemp -d)
pushd $PROJECT_ROOT

rm -f ./updates.img 2>/dev/null

usage() {
    cat <<USAGE
usage: build_updates_img.sh [options]
OPTIONS:
  -p | --python <python_interpreter>  Python interpreter to use. Use to differentiate between Python 2
                                        and Python 3.
  -h | --help                         Print this help text
USAGE
}

SHORT_OPTIONS="hp:"
LONG_OPTIONS="help,python:"

ARGS=$(getopt -s bash --options $SHORT_OPTIONS --longoptions $LONG_OPTIONS -- "$@")

eval set -- $ARGS

while true; do
    case $1 in
        -p|--python)
            # Note to future self, shift moves all positional parameters to n-1
            # (e.g. after shift the value of $1 becomes whatever $2 was prior)
            shift
            PYTHON_BIN=$1;;
        -h|--help)
            usage
            exit;;
        *)
            # Stop parsing on anything other than a long or short option we expected.
            break;;
    esac
    shift
done

if [ "$PYTHON_BIN" = "" ]; then
    PYTHON_BIN="python"
    echo "Python interpreter not specified, using ${PYTHON_BIN}"
fi


# Install files to the temporary build dir
export DESTDIR=$UPDATE_DIR
export PYTHON=$PYTHON_BIN
export PREFIX=/usr
make -e clean
make
make -e install

# Get site-packages dir
PYTHON_SITE_PACKAGE_DIRS=`${PYTHON_BIN} -c "import site; print(' '.join(site.getsitepackages()))"`

# List of required Python packages
PY_PACKAGES="kitchen kitchen-1.2.4-py3.6.egg-info dateutil"

# Copy required Python modules to updates.img too
for pkg in `echo ${PY_PACKAGES}`
do
        for site_pkg_dir in `echo ${PYTHON_SITE_PACKAGE_DIRS}`
        do
                if [ -d "${site_pkg_dir}/${pkg}" ]
                then
                        mkdir -p "${UPDATE_DIR}/${site_pkg_dir}"
                        echo "copying ${site_pkg_dir}/${pkg} to ${UPDATE_DIR}/${site_pkg_dir}"
                        cp -R "${site_pkg_dir}/${pkg}" "${UPDATE_DIR}/${site_pkg_dir}"
                        break
                fi
        done
done

pushd $UPDATE_DIR

# Build img file (See https://fedoraproject.org/wiki/Anaconda/Updates)
find . | cpio -o -c | gzip > $PROJECT_ROOT/updates.img

popd

# Clean up after ourselves
rm -rf $UPDATE_DIR
popd
unset DESTDIR
unset PYTHON
unset PREFIX


