{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    let
      # This only works on Linux for now
      supportedSystems = [ flake-utils.lib.system.x86_64-linux ];
    in 
      flake-utils.lib.eachSystem supportedSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Our base package, which we create by extracting our remote zip file
          egrabberPackage = pkgs.stdenv.mkDerivation {
            name = "egrabber-src";
            version = "1.0.0";

            # Fetch our source zip from S3
            src = pkgs.fetchzip {
              url = "https://public-temp.s3.us-gov-west-1.amazonaws.com/sauron/sauron_egrabber_1_22.zip";
              sha256 = "sha256-5yN5kJfSFhPcljoDKySDWZnNMJQz5eFP9dKn7GaByTU=";
              stripRoot = false;
            };

            nativeBuildInputs = [ pkgs.unzip pkgs.gnutar pkgs.gzip ];

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out
              # Extract the tar.gz file with "egrabber" in it into $out
              for tarfile in *.tar.gz; do
                if [[ "$(basename "$tarfile")" == *egrabber* ]]; then
                  # Strip the folder from the extracted paths so that we get all our essential files
                  # in the derivation root directory instead of in a pointless subdirectory
                  tar -xzf "$tarfile" --strip-components=1
                  break
                fi
              done

              # Extract the other zip file into $out as well
              for zipfile in *.zip; do
                unzip "$zipfile"
              done
              cp -r * $out/
            '';
          };
        in 
        {
          # Include our base package as it can be used for a full system install, such as  
          # compiling its drivers and such.
          packages = {
            inherit egrabberPackage;
            # The root files, which are used by our libraries to link with
            egrabberRoot = pkgs.stdenv.mkDerivation {
              name = "egrabber-core-files";

              # Use our extracted egrabber source as our source code
              src = egrabberPackage;

              installPhase = ''
                mkdir -p $out/{lib,include,bin,firmware,studio,shell,scripts}

                # Copy libraries and CTI files
                cp -r lib/* $out/lib/
                cp -r include/* $out/include/
                cp -r bin/* $out/bin/
                cp -r firmware/stage2/euresys/eGrabber $out/firmware/
                cp -r shell/* $out/shell/
                cp -r scripts/* $out/scripts/
              '';
            };
          };
        }
      );
}
