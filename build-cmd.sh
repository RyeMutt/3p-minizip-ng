#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

MINIZLIB_SOURCE_DIR="minizip-ng"

top="$(pwd)"
stage="$top"/stage

[ -f "$stage"/packages/include/zlib-ng/zlib.h ] || \
{ echo "You haven't yet run 'autobuild install'." 1>&2; exit 1; }

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

# CMake configuration options for all platforms
config=( \
    -DBUILD_SHARED_LIBS=OFF \
    -DMZ_BUILD_TESTS=ON \
    -DMZ_BZIP2=OFF \
    -DMZ_COMPAT=ON \
    -DMZ_FETCH_LIBS=OFF \
    -DMZ_ICONV=OFF \
    -DMZ_LIBBSD=OFF \
    -DMZ_LIBCOMP=OFF \
    -DMZ_LZMA=OFF \
    -DMZ_OPENSSL=OFF \
    -DMZ_PKCRYPT=OFF \
    -DMZ_SIGNING=OFF \
    -DMZ_WZAES=OFF \
    -DMZ_ZSTD=OFF \
    )

pushd "$MINIZLIB_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
            load_vsvars

            cmake -G "Ninja Multi-Config" . \
                  -DCMAKE_C_FLAGS:STRING="$LL_BUILD_RELEASE" \
                  -DCMAKE_CXX_FLAGS:STRING="$LL_BUILD_RELEASE" \
                  "${config[@]}" \
                  -DCMAKE_INSTALL_PREFIX=$(cygpath -m $stage) \
                  -DCMAKE_INSTALL_LIBDIR="$(cygpath -m "$stage/lib/release")" \
                  -DCMAKE_INSTALL_INCLUDEDIR="$(cygpath -m "$stage/include/minizip-ng")" \
                  -DZLIB_INCLUDE_DIRS="$(cygpath -m "$stage/packages/include/zlib-ng/")" \
                  -DZLIB_LIBRARIES="$(cygpath -m "$stage/packages/lib/release/zlib.lib")"


            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            cmake --install . --config Release
        ;;

        # ------------------------- darwin, darwin64 -------------------------
        darwin*)

            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            opts="${TARGET_OPTS:--arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE}"

            cmake ../${MINIZLIB_SOURCE_DIR} -GXcode \
                  -DCMAKE_C_FLAGS:STRING="$(remove_cxxstd $opts)" \
                  -DCMAKE_CXX_FLAGS:STRING="$opts" \
                  "${config[@]}" \
                  -DCMAKE_INSTALL_PREFIX=$stage \
                  -DCMAKE_INSTALL_LIBDIR="$stage/lib/release" \
                  -DCMAKE_INSTALL_INCLUDEDIR="$stage/include/minizip-ng" \
                  -DZLIB_INCLUDE_DIRS="$stage/packages/include/zlib-ng/" \
                  -DZLIB_LIBRARIES="$stage/packages/lib/release/libz.a" \
                  -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                  -DCMAKE_OSX_ARCHITECTURES="x86_64"

            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            cmake --install . --config Release
        ;;            

        # -------------------------- linux, linux64 --------------------------
        linux*)
            # Prefer out of source builds
            rm -rf build
            mkdir -p build
            pushd build
        
            # Default target per autobuild build --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"

            cmake ${top}/${MINIZLIB_SOURCE_DIR} -G"Ninja" \
                  -DCMAKE_C_FLAGS:STRING="$(remove_cxxstd $opts)" \
                  -DCMAKE_CXX_FLAGS:STRING="$opts" \
                  "${config[@]}" \
                  -DCMAKE_INSTALL_PREFIX=$stage \
                  -DCMAKE_INSTALL_LIBDIR="$stage/lib/release" \
                  -DCMAKE_INSTALL_INCLUDEDIR="$stage/include/minizip-ng" \
                  -DZLIB_INCLUDE_DIRS="$stage/packages/include/zlib-ng/" \
                  -DZLIB_LIBRARIES="$stage/packages/lib/release/libz.a"

            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" -eq 0 ]; then
                ctest -C Release
            fi

            cmake --install . --config Release

            popd
        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/minizip-ng.txt"
popd

mkdir -p "$stage"/docs/minizip-ng/
cp -a README.Linden "$stage"/docs/minizip-ng/
