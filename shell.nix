{ pkgs ? import <nixpkgs> { }, ... }:
let
  linuxPkgs = with pkgs; lib.optional stdenv.isLinux (
    inotifyTools
  );
  macosPkgs = with pkgs; lib.optional stdenv.isDarwin (
    with darwin.apple_sdk.frameworks; [
      CoreFoundation
      CoreServices
    ]
  );
in
with pkgs;
mkShell {
  name = "new_darth-shell";
  nativeBuildInputs = [
    ## erlang
    beam.packages.erlangR24.elixir_1_13
    ## node
    nodejs-16_x
    (yarn.override { nodejs = nodejs-16_x; })
    # custom pkg groups
    linuxPkgs
    macosPkgs
  ];
}
