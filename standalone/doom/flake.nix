{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  inputs.zig.url = "github:mitchellh/zig-overlay";

  outputs = { self, nixpkgs, zig, ... }@inputs:
    let
      system = "x86_64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      # zigVersion = "0.16.0";
      zigVersion = "master";
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          zig.packages.${system}.${zigVersion}
          pkgs.zls
          pkgs.git
          pkgs.qemu
          pkgs.lldb
        ];
      };
    };
}
