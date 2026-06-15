{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    odin      # Odin compiler
    ols       # Odin Language Server
    llvm      # Required by Odin for backend code generation
    renderdoc # Optional graphic debugging
    glfw      # Common for windowing
    gcc_multi
    binutils
    qemu
  ];


  shellHook = ''
    export ODIN_ROOT="${pkgs.odin}/share"
  '';
}

