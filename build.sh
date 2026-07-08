#!/bin/sh
set -e

if [ -z $1 ] 
then
	BUILD_TYPE=Distribution
else
	BUILD_TYPE=$1
	shift
fi

if [ -z "$EMSCRIPTEN_ROOT" ]; then
	if [ -d "/opt/homebrew/opt/emscripten/libexec" ]; then
		EMSCRIPTEN_ROOT=/opt/homebrew/opt/emscripten/libexec
	elif [ -n "$EMSDK" ]; then
		EMSCRIPTEN_ROOT=$EMSDK/upstream/emscripten
	else
		echo "Error: set EMSCRIPTEN_ROOT or EMSDK" >&2; exit 1
	fi
fi
EMSCRIPTEN_ARGS="-DEMSCRIPTEN_ROOT=$EMSCRIPTEN_ROOT -DCMAKE_TOOLCHAIN_FILE=$EMSCRIPTEN_ROOT/cmake/Modules/Platform/Emscripten.cmake"

rm -rf ./dist

mkdir dist

MEMORY_ARGS="-DALLOW_MEMORY_GROWTH=ON -DINITIAL_MEMORY=268435456"

if [ $BUILD_TYPE != "Debug" ]
then
	cmake -B Build/Debug/ST -DCMAKE_BUILD_TYPE=Debug -DBUILD_WASM_COMPAT_ONLY=ON $EMSCRIPTEN_ARGS $MEMORY_ARGS "${@}"
	cmake --build Build/Debug/ST -j`nproc`

	cmake -B Build/Debug/MT -DENABLE_MULTI_THREADING=ON -DENABLE_SIMD=ON -DCMAKE_BUILD_TYPE=Debug -DBUILD_WASM_COMPAT_ONLY=ON $EMSCRIPTEN_ARGS $MEMORY_ARGS "${@}"
	cmake --build Build/Debug/MT -j`nproc`

	mv ./dist/jolt-physics.wasm-compat.js ./dist/jolt-physics.debug.wasm-compat.js
	mv ./dist/jolt-physics.multithread.wasm-compat.js ./dist/jolt-physics.debug.multithread.wasm-compat.js
fi

cmake -B Build/$BUILD_TYPE/ST -DCMAKE_BUILD_TYPE=$BUILD_TYPE $EMSCRIPTEN_ARGS $MEMORY_ARGS "${@}"
cmake --build Build/$BUILD_TYPE/ST

cmake -B Build/$BUILD_TYPE/MT -DENABLE_MULTI_THREADING=ON -DENABLE_SIMD=ON -DCMAKE_BUILD_TYPE=$BUILD_TYPE $EMSCRIPTEN_ARGS $MEMORY_ARGS "${@}"
cmake --build Build/$BUILD_TYPE/MT

if [ $BUILD_TYPE = "Debug" ]
then
	cp ./dist/jolt-physics.wasm-compat.js ./dist/jolt-physics.debug.wasm-compat.js
	cp ./dist/jolt-physics.multithread.wasm-compat.js ./dist/jolt-physics.debug.multithread.wasm-compat.js
fi

# Update the worker URL in the copied wasm-compat.js files
sed -i "" 's:jolt-physics.multithread.wasm-compat.js:jolt-physics.debug.multithread.wasm-compat.js:g' ./dist/jolt-physics.debug.multithread.wasm-compat.js

cat > ./dist/jolt-physics.d.ts << EOF
import Jolt from "./types";

export default Jolt;
export * from "./types";

EOF

cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.wasm.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.wasm-compat.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.debug.wasm-compat.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.multithread.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.multithread.wasm.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.multithread.wasm-compat.d.ts
cp ./dist/jolt-physics.d.ts ./dist/jolt-physics.debug.multithread.wasm-compat.d.ts

cp ./dist/jolt-physics*.wasm-compat.js ./Examples/js/
