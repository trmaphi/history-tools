from ubuntu:18.04 as builder

workdir /root
run apt-get update && apt-get install -y wget gnupg
run wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

run echo '\n\
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic main\n\
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic main\n\
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main\n\
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main\n' >>/etc/apt/sources.list

run apt-get update && apt-get install -y \
    autoconf2.13                \
    build-essential             \
    bzip2                       \
    cargo                       \
    clang-8                     \
    git                         \
    libgmp-dev                  \
    libpq-dev                   \
    lld-8                       \
    lldb-8                      \
    ninja-build                 \
    nodejs                      \
    npm                         \
    pkg-config                  \
    postgresql-server-dev-all   \
    python2.7-dev               \
    python3-dev                 \
    rustc                       \
    zlib1g-dev

run update-alternatives --install /usr/bin/clang clang /usr/bin/clang-8 100
run update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-8 100

workdir /root
run wget https://dl.bintray.com/boostorg/release/1.69.0/source/boost_1_69_0.tar.gz
run tar xf boost_1_69_0.tar.gz
workdir /root/boost_1_69_0
run ./bootstrap.sh
run ./b2 toolset=clang -j10 install

workdir /root
run wget https://github.com/Kitware/CMake/releases/download/v3.14.5/cmake-3.14.5.tar.gz
run tar xf cmake-3.14.5.tar.gz
workdir /root/cmake-3.14.5
run ./bootstrap --parallel=10
run make -j10
run make -j10 install

workdir /root
run wget https://archive.mozilla.org/pub/firefox/releases/64.0/source/firefox-64.0.source.tar.xz
run tar xf firefox-64.0.source.tar.xz
workdir /root/firefox-64.0/js/src/
run autoconf2.13

run mkdir build_REL.OBJ
workdir /root/firefox-64.0/js/src/build_REL.OBJ
run SHELL=/bin/bash ../configure --disable-debug --enable-optimize --disable-jemalloc --disable-replace-malloc
run SHELL=/bin/bash make -j10
run SHELL=/bin/bash make install

workdir /root
run wget https://github.com/EOSIO/eos/releases/download/v1.8.1/eosio_1.8.1-1-ubuntu-18.04_amd64.deb
run apt-get install -y ./eosio_1.8.1-1-ubuntu-18.04_amd64.deb

workdir /root
run wget https://github.com/EOSIO/eosio.cdt/releases/download/v1.6.1/eosio.cdt_1.6.1-1_amd64.deb
run apt-get install -y ./eosio.cdt_1.6.1-1_amd64.deb

workdir /root
run mkdir /root/history-tools
copy . /root/history-tools
run mkdir /root/history-tools/build
workdir /root/history-tools/build
run cmake -GNinja -DCMAKE_CXX_COMPILER=clang++-8 -DCMAKE_C_COMPILER=clang-8 ..
run bash -c "cd ../src && npm install node-fetch"
run ninja
run bash -c "cd ../demo-gui && npm i && npm run build"

# Final image
from ubuntu:18.04
run apt-get update && apt-get install -y libssl1.0.0

workdir /root
run mkdir history-tools
workdir /root/history-tools
run mkdir build
run mkdir src
run mkdir -p demo-gui/dist
workdir /root/history-tools/build

copy --from=builder /usr/local/lib/libmozjs-64.so /usr/local/lib/
copy --from=builder /root/history-tools/src/glue.js /root/history-tools/src/
copy --from=builder /root/history-tools/src/query-config.json /root/history-tools/src/
copy --from=builder /root/history-tools/build/combo-rocksdb /root/history-tools/build/
copy --from=builder /root/history-tools/build/fill-rocksdb /root/history-tools/build/
copy --from=builder /root/history-tools/build/wasm-ql-rocksdb /root/history-tools/build/
copy --from=builder /root/history-tools/build/chain-server.wasm /root/history-tools/build/
copy --from=builder /root/history-tools/build/legacy-server.wasm /root/history-tools/build/
copy --from=builder /root/history-tools/build/token-server.wasm /root/history-tools/build/
copy --from=builder /root/history-tools/demo-gui/dist/chain-client.wasm /root/history-tools/demo-gui/dist/
copy --from=builder /root/history-tools/demo-gui/dist/client.bundle.js /root/history-tools/demo-gui/dist/
copy --from=builder /root/history-tools/demo-gui/dist/index.html /root/history-tools/demo-gui/dist/
copy --from=builder /root/history-tools/demo-gui/dist/token-client.wasm /root/history-tools/demo-gui/dist/

env LD_LIBRARY_PATH=/usr/local/lib
expose 80/tcp
entrypoint ["./combo-rocksdb", "--wql-static-dir", "../demo-gui/dist/", "--wql-listen", "0.0.0.0:80"]
