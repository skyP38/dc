{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    flutter
    clang
    cmake
    ninja
    gtk3
    pcre2
    pkg-config
    glib
    libsysprof-capture
  ];
}
