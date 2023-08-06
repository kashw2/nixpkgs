{ lib, rustPlatform, fetchFromGitHub, pkg-config, pkgs }:

rustPlatform.buildRustPackage rec {
    pname = "neon";
    version = "release-3592";

    preConfigure = ''
        export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"
        export PROTOC="${pkgs.protobuf}/bin/protoc"
        export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib";
    '';

LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib";

    nativeBuildInputs = [
        pkg-config
        pkgs.glibc
        pkgs.libxc
        pkgs.gcc
        pkgs.clang
        pkgs.cmake
    ];

    buildInput = with pkgs; [
        protobuf
        openssl.dev
        flex
        bison
        libseccomp
        llvmPackages.libclang
    ];

    src = fetchFromGitHub {
        owner = "neondatabase";
        repo = pname;
        rev = version;
        sha256 = "IC5K3E47St0EizJeP1SjZ9DZnLcIrlOKWza3X/bZTKw=";
    };

    cargoLock = {
        lockFile = ./Cargo.lock;
        outputHashes = {
            "heapless-0.8.0" = "sha256-phCls7RQZV0uYhDEp0GIphTBw0cXcurpqvzQCAionhs=";
            "postgres-0.19.4" = "sha256-sX8/e1UE9DhotHRYdz8o/Ui+jgJgzF2wLnTyiXwWdMg=";
        };
    };

    cargoHash = lib.fakeHash;

    meta = with lib; {
        description = "Neon: Serverless Postgres. We separated storage and compute to offer autoscaling, branching, and bottomless storage.";
        homepage = "https://github.com/neondatabase/neon";
        license = licenses.asl20;
        maintainers = [];        
    };

}