{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    flutter
    clang
    cmake
    ninja
    gtk3
    pkg-config
    glib
    libsysprof-capture
  ];
}
