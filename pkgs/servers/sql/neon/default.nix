{ 
stdenv
, lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, cmake
, readline
, zlib
, openssl
, libseccomp
, perl
, bison
, flex
, coreutils
 }:

stdenv.mkDerivation rec {
    pname = "neon";
    version = "3592";

    preConfigure = ''
        BUILD_TYPE="release make -j`nproc` -s"
        ROOT_PROJECT_DIR = "./"
    '';

    postConfigure = ''
        LD_LIBRARY_PATH="$out/pg_install/bin;$out/pg_install/lib"
    '';

    src = fetchFromGitHub {
        owner = "neondatabase";
        repo = pname;
        rev = "release-${version}";
        hash = "sha256-KcUbfUy8PuPXQmtFK0hlFsJpddgb2w+zyY4JJjkG7Lw=";
        fetchSubmodules = true;
    };

    nativeBuildInputs = [ perl bison flex ];

    buildInputs = [ readline zlib openssl libseccomp ];

    configurePhase = ''
        substituteInPlace /build/source/vendor/postgres-v14/configure \
            --replace "/bin/pwd" "${coreutils}/bin/pwd"
        substituteInPlace /build/source/vendor/postgres-v15/configure \
            --replace "/bin/pwd" "${coreutils}/bin/pwd"
        '';

    buildPhase = ''
        make -j`nproc` -s
    '';

    meta = with lib; {
        description = "Neon: Serverless Postgres. We separated storage and compute to offer autoscaling, branching, and bottomless storage.";
        homepage = "https://github.com/neondatabase/neon";
        license = licenses.asl20;
        maintainers = with maintainers; [ kashw2 ];        
    };

}