(import ./default.nix).shellFor {
  tools = {
    cabal = "3.6.2.0";
    hlint = "latest";
    ghcid = "latest";
    #haskell-language-server = "latest";
  };
}
