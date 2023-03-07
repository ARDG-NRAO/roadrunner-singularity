export CUDA_ARCH='Ampere86'
export CASAROOT=/casa_builds/roadrunner
export CASAINSTALL=${CASAROOT}/linux_64b  # (bash, zsh, POSIX shell)
export CASASRC=${CASAROOT}/casa6    # (bash, zsh, POSIX shell)
export CASATESTDIR=${CASAROOT}/test       # (bash, zsh, POSIX shell)
export CASABUILD=${CASAROOT}/build # (bash, zsh, POSIX shell)

export NCORES=16

if [ -d "$CASABUILD" ]; then rm -Rf $CASABUILD; fi

mkdir -p $CASAROOT $CASAINSTALL $CASASRC $CASATESTDIR $CASABUILD

cd $CASAROOT

git clone --recursive https://open-bitbucket.nrao.edu/scm/casa/casa6.git --branch ARD-33-DR ${CASASRC}

####### Install Kokkos ########
# Depending on what you set the CUDA_ARCH variable kokkos will build optimizations for that.

git clone --branch release-candidate-3.7.02 https://github.com/kokkos/kokkos.git

cd kokkos

sed -i 's/sm_35/sm_70/g' $CASAROOT/kokkos/bin/nvcc_wrapper

export KOKKOS-ROOT-DIR=$PWD

mkdir -p $CASABUILD/kokkos
cd $CASABUILD/kokkos

cmake -DKokkos_ENABLE_CUDA_LAMBDA=ON  -DKokkos_ARCH_AMPERE86=ON -DKokkos_ENABLE_CUDA=ON  -DKokkos_ENABLE_OPENMP=ON -DKokkos_ENABLE_SERIAL=ON  -DCMAKE_INSTALL_PREFIX=$CASAINSTALL  -DBUILD_SHARED_LIBS=ON $CASAROOT/kokkos/

make -j $NCORES install


###### Install FFTW for HPG ########
# turns out the --configure install avoids missing cmake errors. Not needed for HPG 1.2.2 so can ignore.
# On RHEL* machines with fftw-devel install it can't find it for libsynthesis so still useful
cd $CASAROOT

export FFTW_VERSION=3.3.10

curl -L http://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz | tar xz

cd fftw-${FFTW_VERSION}

./configure --enable-shared --enable-threads --enable-openmp --prefix=$PWD

make -j $NCORES install

####### Install HPG ########
### HPG finds FFTW but can't find the double double version. So I am going to build locally.

cd $CASAROOT

git clone --branch v1.2.2 https://gitlab.nrao.edu/mpokorny/hpg.git

mkdir -p $CASABUILD/hpg
cd $CASABUILD/hpg


cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$CASAINSTALL -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_COMPILER=$CASAINSTALL/bin/nvcc_wrapper -DCMAKE_PREFIX_PATH=$CASAINSTALL -DFFTW_ROOT_DIR=$CASAROOT/fftw-${FFTW_VERSION} ${CASAROOT}/hpg/

make -j 16 install
####### Install parafeed ########

cd $CASAROOT


git clone  https://github.com/sanbee/parafeed.git

mkdir -p $CASABUILD/parafeed
cd $CASABUILD/parafeed


cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=$CASAINSTALL -DBUILD_SHARED_LIBS=ON ${CASAROOT}/parafeed/

make -j 16 install
####### Install libsakura #######
cd $CASAROOT

curl -L https://github.com/tnakazato/sakura/archive/refs/tags/libsakura-5.1.3.tar.gz | gunzip | tar -xvf -

cd sakura-libsakura*/libsakura
mkdir -p build
cd build
cmake  \
    -DCMAKE_INSTALL_PREFIX=$CASAINSTALL \
    -DBUILD_DOC:BOOL=OFF \
    -DPYTHON_BINDING:BOOL=OFF \
    -DSIMD_ARCH=GENERIC \
    -DENABLE_TEST:BOOL=OFF \
    ..

make install -j ${NCORES}

####### Install Measures Data & Build CASACORE ######

mkdir -p $CASAINSTALL/data
curl ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar | tar -C $CASAINSTALL/data -xzf -

mkdir -p $CASABUILD/casacore
cd $CASABUILD/casacore

 
cmake \
    -DCMAKE_INSTALL_PREFIX=$CASAINSTALL \
    -DDATA_DIR=$CASAINSTALL/data \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DUSE_OPENMP=ON \
    -DUSE_THREADS=ON \
    -DCMAKE_CXX_FLAGS="-fno-tree-vrp" \
    -DBUILD_FFTPACK_DEPRECATED=ON \
    -DBUILD_TESTING=ON \
    -DBUILD_PYTHON3=OFF \
    -DBUILD_DYSCO=ON \
    -DUseCcache=1 \
    $CASASRC/casatools/casacore

make install -j ${NCORES}

####### CLONE CASA6 INSTALL CASACPP ##############

mkdir -p $CASABUILD/casacpp
cd $CASABUILD/casacpp
export PATH=/usr/lib64/openmpi/bin/:$PATH   # This is not needed in Debian or Ubuntu and is optional in the other platforms if no MPI support at the C++ level is needed
 
PKG_CONFIG_PATH=$CASAINSTALL/lib/pkgconfig cmake \
     -DCMAKE_INSTALL_PREFIX=$CASAINSTALL \
     -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=$CASAINSTALL \
     -DFFTW_ROOT_DIR=$CASAROOT/fftw-${FFTW_VERSION} \
     -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      $CASASRC/casatools/src/code
 
make install -j ${NCORES}

####### package and produce a standlone package using exodus #############

#micromamba activate casapy

#exodus --tarball $CASABUILD/casacpp/synthesis/tRoadRunner --output $CASABUILD/roadrunner.tar.gz
