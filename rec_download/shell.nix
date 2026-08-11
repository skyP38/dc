{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.gcc
    pkgs.luajit
    pkgs.pkg-config
    pkgs.go
    pkgs.luajitPackages.tl
  ];

  shellHook = ''
    export PKG_CONFIG_PATH="${pkgs.luajit}/lib/pkgconfig:$PKG_CONFIG_PATH"
  '';
}
