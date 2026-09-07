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

    tmux = {
      enable = true;
      baseIndex = 1;
      mouse = true;
      newSession = true;
      clock24 = true;
      keyMode = "vi";
      terminal = "tmux-256color";
      historyLimit = 10000;
      extraConfig = ''
        set -g set-clipboard on
        set -as terminal-features ",*:RGB"
      '';
      plugins = with pkgs; [
        {
          plugin = tmuxPlugins.catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavor "macchiato"
          '';
        }
      ];
    };

    zsh = {
      enable = true;
      oh-my-zsh.enable = true;
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
