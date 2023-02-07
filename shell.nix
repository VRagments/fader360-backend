{ pkgs ? import <nixpkgs> { }, ... }:
let
  linuxPkgs = with pkgs; lib.optional stdenv.isLinux (
    inotify-tools
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
    beam.packages.erlangR25.elixir_1_14
    ## node
    nodejs-16_x
    (yarn.override { nodejs = nodejs-16_x; })
    ## ffmpeg
    ffmpeg
    ## tools
    bc
    imagemagick
    # custom pkg groups
    linuxPkgs
    macosPkgs

    # used for communicating with the managed Docker repository on Google Cloud Platform
    google-cloud-sdk
  ];
}
