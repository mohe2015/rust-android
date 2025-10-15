{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in rec {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

      packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

      # ~/Android/Sdk/platforms/android-36/android.jar
      packages.x86_64-linux.android-jar = let
        base64 = pkgs.fetchurl {
        url = "https://android.googlesource.com/platform/prebuilts/sdk/+/refs/heads/android16-release/36/public/android.jar?format=TEXT";
        hash = "sha256-ZFX0cUU6/cfdeq5RR5nfZhsyqDvmvqPkvWsjdBl93JE=";
      }; in pkgs.runCommandLocal "android.jar" {} ''
        base64 -d ${base64} > $out
      '';

      packages.x86_64-linux.apk = pkgs.runCommand "result.apk" {} ''
          APK_SOURCE=$(mktemp -d)
          APK_DESTINATION=$(mktemp --suffix .zip)
          rm "$APK_DESTINATION"

          ${pkgs.aapt}/bin/aapt2 link --output-to-dir -o "$APK_SOURCE" -I ${packages.x86_64-linux.android-jar} --manifest ${./AndroidManifest.xml}

          (cd "$APK_SOURCE" && ${pkgs.zip}/bin/zip -r "$APK_DESTINATION" .)
          cp "$APK_DESTINATION" $out
      '';

      # nix run .#build-apk
      packages.x86_64-linux.build-apk = nixpkgs.legacyPackages.x86_64-linux.writeShellApplication {
        name = "build-apk";
        text = ''
          cp ${packages.x86_64-linux.apk} result.apk
        '';
      };
    };
}
