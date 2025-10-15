{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

      packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

      # nix run .#build-apk
      packages.x86_64-linux.build-apk = nixpkgs.legacyPackages.x86_64-linux.writeShellApplication {
        name = "build-apk";
        text = ''
          set -ex
          APK_SOURCE=$(mktemp -d)
          APK_DESTINATION=$(mktemp --suffix .zip)
          rm "$APK_DESTINATION"
          (cd "$APK_SOURCE" && ${pkgs.zip}/bin/zip -r "$APK_DESTINATION" .)
          cp "$APK_DESTINATION" result.apk
        '';
      };
    };
}
