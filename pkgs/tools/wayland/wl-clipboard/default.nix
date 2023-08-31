{ lib
, stdenv
, fetchFromGitHub
, fetchpatch
, meson
, ninja
, pkg-config
, wayland
, wayland-protocols
, wayland-scanner
, xdg-utils
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "wl-clipboard";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "bugaevc";
    repo = "wl-clipboard";
    rev = "v${version}";
    hash = "sha256-BYRXqVpGt9FrEBYQpi2kHPSZyeMk9o1SXkxjjcduhiY=";
  };

  strictDeps = true;
  nativeBuildInputs = [ meson ninja pkg-config wayland-scanner makeWrapper ];
  buildInputs = [ wayland wayland-protocols ];

  mesonFlags = [
    "-Dfishcompletiondir=share/fish/vendor_completions.d"
  ];

  # Fix for https://github.com/NixOS/nixpkgs/issues/251261
  postInstall = ''
    wrapProgram $out/bin/wl-copy \
      --suffix PATH : ${xdg-utils}/bin/xdg-mime
  '';

  patches = [
    (fetchpatch {
      url = "https://github.com/bugaevc/wl-clipboard/pull/192.patch";
      hash = "sha256-IX6Jyre0HNYjy8Qa7UhcdTLU5I4/MnNiaaHr6zKHa5U=";
      name = "mime-type-fix.patch";
    })
  ];

  meta = with lib; {
    homepage = "https://github.com/bugaevc/wl-clipboard";
    description = "Command-line copy/paste utilities for Wayland";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ dywedir kashw2];
    platforms = platforms.unix;
  };
}
