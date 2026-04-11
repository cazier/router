{
  lib,
  pkgs,
  username,
  ...
}: {
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };
  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = "Brendan Cazier";
          email = "520246+cazier@users.noreply.github.com";
          signingkey = "BEE9B4318BDF9F29";
        };
        credential.helper = "store";
        init.defaultbranch = "main";
        commit.gpgsign = true;
        safe.directory = "/etc/nixos";
      };
    };

    gpg.enable = true;
    starship.enable = true;

    zsh = {
      enable = true;
      history = {
        append = true;
        saveNoDups = true;
      };
      plugins = with pkgs; [
        {
          name = "zsh-completions";
          src = zsh-completions;
        }
      ];
      initContent = lib.mkOrder 1400 ''
        bindkey '^[OA' history-search-backward
        bindkey '^[OB' history-search-forward
        bindkey '^[[1;5D' backward-word
        bindkey '^[[1;5C' forward-word
      '';
      shellAliases = {
        cd = "pushd";
        ll = "ls -lah";
        gst = "git status";
        gp = "git push";
      };
    };
  };
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
