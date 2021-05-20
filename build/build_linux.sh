#!/bin/sh

C_COMPILER=icx
CXX_COMPILER=dpcpp
LINKER=dpcpp

# Default options are
# -DUSE_OPENMP=OFF -DUSE_GTEST=ON

CXX_FLAGS=
CPU_OPTIONS=
MIC_OPTIONS=

CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | sed 's/^.*: //')
NUM_CORES=$(grep processor /proc/cpuinfo | wc -l)
CPU_FLAGS=$(grep flags /proc/cpuinfo | uniq)

command_exists () {
    type $1 > /dev/null 2>&1;
}


if [ "$CPU_VENDOR" = "GenuineIntel" ] && [ "$CPU_FLAGS" = *"avx"* ] && [ "$CPU_OPTIONS" != *"-DUSE_AVX="* ]; then
    CPU_OPTIONS="-DUSE_AVX=ON $CPU_OPTIONS"
fi

clean=false
python_path="python"
USE_FFTW="OFF"
USE_MKL="OFF"
USE_OMP="OFF"
USE_TESTS="OFF"
USE_PTESTS="OFF"

USE_PYTHON_INTERFACE="ON"

script=$0

while [ $# -gt 0 ]
do
key="$1"

case $key in
    -openmp)
    USE_OMP="ON"
    shift # past argument
    ;;
    -python)
    python_path="$2"
    shift # past argument
    shift # past value
    ;;
    -fftw)
    USE_FFTW="ON"
    shift # past argument
    ;;
    -mkl_fft)
    USE_MKL="ON"
    shift # past argument
    ;;
    -tests)
    USE_TESTS="ON"
    shift # past argument
    ;;
    -ptests)
    USE_PTESTS="ON"
    shift # past argument
    ;;
    *)    # unknown option
    shift # past argument
    ;;
esac
done

if [ $USE_OMP = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_OMP=ON"
    CXX_FLAGS="-fiopenmp"
fi
if [ $USE_FFTW = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_FFTW=ON"
fi
if [ $USE_MKL = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_MKL=ON"
fi
if [ $USE_TESTS = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_TESTS=ON"
fi
if [ $USE_PTESTS = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_PTESTS=ON -DBENCHMARK_ENABLE_TESTING=OFF"
fi

if [ $USE_PYTHON_INTERFACE = "ON" ]; then
    CPU_OPTIONS="$CPU_OPTIONS -DUSE_PYTHON_INTERFACE=ON"
fi

CPU_OPTIONS="$CPU_OPTIONS -DCMAKE_BUILD_TYPE=Release -DPYTHON_EXECUTABLE:FILEPATH=$python_path"


BUILD_DIR="unix_makefiles"
if [ ! -d $BUILD_DIR ]; then
    mkdir -p $BUILD_DIR
fi
cd $BUILD_DIR

#recommended key for bes performance
#-mprefer-vector-width=512 && (-xCOMMON-AVX512 || -xCORE-AVX2)
#CXX_FLAGS="$CXX_FLAGS -mprefer-vector-width=512 -xCOMMON-AVX512 -O3 -ffp-contract=fast -mfma -ffast-math -fma -debug=full"

CXX=$CXX_COMPILER CC=$C_COMPILER LD=$LINKER cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS=$CXX_FLAGS -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 -DCOMPILE_HAVE_GNU_POSIX_REGEX=0 -G "Unix Makefiles" $CPU_OPTIONS ../..
make -j $NUM_CORES -k 2> /dev/null
if [ $? -ne 0 ]; then
    make
fi
mkdir -p ../../bin
cp src/pyHiChi/pyHiChi.so ../../bin/pyHiChi.so
cd ..

if $clean ; then
    BUILD_DIR="unix_makefiles"
    if [ -d $BUILD_DIR ]; then
        rm -rf $BUILD_DIR
    fi
fi
