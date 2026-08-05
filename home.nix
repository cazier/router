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
    packages = with pkgs; [
      prek
    ];
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
        diff.external = "${pkgs.difftastic}/bin/difft";
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
      historySubstringSearch = {
        enable = true;
        searchUpKey = "$terminfo[kcuu1]";
        searchDownKey = "$terminfo[kcud1]";
      };
      plugins = with pkgs; [
        {
          name = "zsh-completions";
          src = zsh-completions;
        }
      ];
      shellAliases = {
        cd = "pushd";
        ll = "ls -lah";
        gst = "git status";
        gp = "git push";
        cat = "bat";
      };
    };
  };
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
