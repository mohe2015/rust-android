{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let pkgs = import nixpkgs {
      system = "x86_64-linux";
      config = {
        android_sdk.accept_license = true; # TODO FIXME build all from source
        allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "android-sdk-cmdline-tools"
          "android-sdk-platform-tools"
          "platform-tools"
          "android-sdk-tools"
          "tools"
          "android-sdk-build-tools"
          "build-tools"
          "android-sdk-platforms"
          "platforms"
          "cmake"
          "cmdline-tools"
        ];
      };
    };
    in rec {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

      packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

      packages.x86_64-linux.buildTools = (pkgs.androidenv.composeAndroidPackages {
        
      }).androidsdk;

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
          ${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/zipalign -v -p 4 "$APK_DESTINATION" $out
      '';

      packages.x86_64-linux.setup-signing-key = pkgs.writeShellApplication {
        name = "setup-signing-key";
        text = ''
          ${pkgs.jdk}/bin/keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-alias
        '';
      };

      # nix run .#build-apk
      packages.x86_64-linux.build-apk = nixpkgs.legacyPackages.x86_64-linux.writeShellApplication {
        name = "build-apk";
        text = ''
          ${pkgs.apksigner}/bin/apksigner sign --ks my-release-key.jks --out my-app-release.apk my-app-unsigned-aligned.apk
          ${pkgs.apksigner}/bin/apksigner verify my-app-release.apk
          cp ${packages.x86_64-linux.apk} result.apk
        '';
      };
    };
}
