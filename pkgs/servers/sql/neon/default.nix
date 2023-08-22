{ 
stdenv
, lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, cmake
, postgresql_14
 }:

stdenv.mkDerivation rec {
    pname = "neon";
    version = "3592";

    src = fetchFromGitHub {
        owner = "neondatabase";
        repo = pname;
        rev = "release-${version}";
        sha256 = "IC5K3E47St0EizJeP1SjZ9DZnLcIrlOKWza3X/bZTKw=";
        deepClone = true;
    };

    nativeBuildInputs = [ postgresql_14 ];

    buildPhase = ''
        make
    '';

    meta = with lib; {
        description = "Neon: Serverless Postgres. We separated storage and compute to offer autoscaling, branching, and bottomless storage.";
        homepage = "https://github.com/neondatabase/neon";
        license = licenses.asl20;
        maintainers = [];        
    };

}