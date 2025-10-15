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

      packages.x86_64-linux.apk = pkgs.runCommand "result.apk" {
        nativeBuildInputs = [ pkgs.jdk ];
      } ''
          APK_SOURCE=$(mktemp -d)
          CLASSES=$(mktemp -d)
          APK_DESTINATION=$(mktemp --suffix .zip)
          rm "$APK_DESTINATION"

          ${pkgs.jdk}/bin/javac -d "$CLASSES" -classpath ${packages.x86_64-linux.android-jar} ${./src/de/selfmade4u/rust}/*.java
          ${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/d8 $CLASSES/*.class --output "$APK_SOURCE"

          ${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/aapt2 link --output-to-dir -o "$APK_SOURCE" -I ${packages.x86_64-linux.android-jar} --manifest ${./AndroidManifest.xml}

          (cd "$APK_SOURCE" && ${pkgs.zip}/bin/zip -r "$APK_DESTINATION" .)
          ${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/zipalign -p -f -v 4 "$APK_DESTINATION" $out
      ''; # maybe the nix build does evil stuff to the apk?

      packages.x86_64-linux.setup-signing-key = pkgs.writeShellApplication {
        name = "setup-signing-key";
        text = ''
          ${pkgs.jdk}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
        '';
      };

      # nix run .#build-apk
      packages.x86_64-linux.build-apk = nixpkgs.legacyPackages.x86_64-linux.writeShellApplication {
        name = "build-apk";
        runtimeInputs = [ pkgs.jdk ];
        text = ''
          ${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/apksigner sign --verbose --v3-signing-enabled false --v4-signing-enabled false --verbose --ks debug.keystore --ks-pass pass:android --out result.apk ${packages.x86_64-linux.apk}
          #${packages.x86_64-linux.buildTools}/libexec/android-sdk/build-tools/36.0.0/apksigner verify -v --print-certs -v4-signature-file result.apk.idsig result.apk
          cp ${packages.x86_64-linux.apk} result.apk
        '';
      };

      packages.x86_64-linux.install-apk = pkgs.writeShellApplication {
        name = "install-apk";
        text = ''
          ${packages.x86_64-linux.build-apk.text}
          ${packages.x86_64-linux.buildTools}/bin/adb install result.apk
        '';
      };
    };
}
