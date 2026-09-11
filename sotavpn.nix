{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "sotavpn";
  version = "1.8.0";

  src = pkgs.fetchurl {
    url = "https://storage.sota.ac/api/v1/public/storage/sotavpn-latest-x64.pkg.tar.zst";
    sha256 = "sha256-riy17Nn+jKi7KlXBrSaITqDgVjGqSHAeyJT6CTc6BsI=";
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.patchelf
    pkgs.zstd
  ];

  # Non-free Flutter GUI needing the usual GTK stack + AppIndicator tray, and
  # the bundled sing-box/sotad linkage. libjvm.so is intentionally NOT added:
  # the package is distributed as an Arch pkg depending only on
  # gtk3/glib2/libayatana-appindicator, so the JNI reference must be a lazy
  # optional (Arch systems don't ship a JVM either).
  buildInputs = with pkgs; [
    gtk3
    glib
    gdk-pixbuf
    pango
    cairo
    atk
    libepoxy
    harfbuzz
    fontconfig
    libayatana-appindicator
    libayatana-indicator
    ayatana-ido
    libdbusmenu
    curl
    zlib
    stdenv.cc.cc.lib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    # Daemon tree. sotad + sing-box ship side by side; sotad locates sing-box
    # relative to its own dir / the working directory, so the pairing must be
    # preserved and the unit runs with WorkingDirectory set there.
    mkdir -p $out/bin $out/libexec/sota-daemon $out/lib/sota-connect $out/share
    cp usr/libexec/sota-daemon/sotad usr/libexec/sota-daemon/sing-box $out/libexec/sota-daemon/
    chmod 755 $out/libexec/sota-daemon/*
    ln -s $out/libexec/sota-daemon/sotad $out/bin/sotad

    # GUI tree. Keep the vendor's exact relative layout: the launcher resolves
    # the bundled lib/ plugins and data/ assets via $ORIGIN rpaths.
    cp -r usr/lib/sota-connect/. $out/lib/sota-connect/
    chmod +x $out/lib/sota-connect/sotavpn 2>/dev/null || true
    find $out/lib/sota-connect/lib -type f -exec chmod +x {} + 2>/dev/null || true

    ln -s $out/lib/sota-connect/sotavpn $out/bin/sotavpn

    # Desktop entry + icons. The vendor entry hardcodes /usr/bin/sotavpn.
    cp -r usr/share/. $out/share/
    sed -i "s|/usr/bin/sotavpn|$out/bin/sotavpn|" $out/share/applications/*.desktop

    runHook postInstall
  '';

  # The Flutter JNI glue (libdartjni.so, libgtk_plugin.so) carries an inert
  # DT_NEEDED libjvm.so that no runtime asset actually uses (the shipped
  # native_assets.json/NativeAssetsManifest.json are both empty), and Arch
  # (the package's target distro) has no JVM either. Strip the NEEDED entry so
  # the bundled plugins dlopen cleanly without dragging in a JRE.
  postInstall = ''
    for so in $out/lib/sota-connect/lib/*.so; do
      if patchelf --print-needed "$so" 2>/dev/null | grep -q '^libjvm.so$'; then
        echo "sotavpn: removing inert libjvm NEEDED from $(basename "$so")"
        patchelf --remove-needed libjvm.so "$so"
      fi
    done
  '';

  meta = {
    description = "Sota Connect - secure and private internet connectivity (sotavpn client + sotad daemon)";
    homepage = "https://sotavpn.net/";
    license = pkgs.lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sotavpn";
  };
}