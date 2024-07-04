{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  undmg,
  unzip
}:

let
  pname = "responsively-desktop";
  version = "1.11.1";
  meta = {
    description = "A modified web browser that helps in responsive web development";
    mainProgram = "responsively-desktop";
    homepage = "https://responsively.app/";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ kashw2 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
  linux = appimageTools.wrapType2 rec {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/responsively-org/responsively-app-releases/releases/download/v${version}/ResponsivelyApp-${version}.AppImage";
      sha256 = "sha256-PM0Cqrz/1AgQmDJdeA1VQCHTiLY7BhtNN1JxxilQNfM=";
    };

    appimageContents = appimageTools.extract { inherit pname version src; };

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/responsivelyapp.desktop $out/share/applications/responsivelyapp.desktop
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/responsivelyapp.png \
        $out/share/icons/hicolor/512x512/apps/responsivelyapp.png
      substituteInPlace $out/share/applications/responsivelyapp.desktop \
        --replace 'Exec=AppRun' 'Exec=${pname}'
    '';

    meta = meta // { platforms = [ "x86_64-linux" ]; };
  };
  darwin = stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/responsively-org/responsively-app-releases/releases/download/v${version}/ResponsivelyApp-${version}.dmg";
      sha256 = "sha256-rosG7l/iTCOwmqE1Z4OdpanTFXC2A87cfJR9R+/kjNs=";
    };

    sourceRoot = "ResponsivelyApp.app";

    nativeBuildInputs = [ makeWrapper undmg ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/bin
      cp -R . $out/Applications/ResponsievelyApp.app
      runHook postInstall
    '';

    meta = meta // { platforms = [ "aarch64-darwin" ]; };
  };
in
if stdenv.isDarwin then darwin else linux
