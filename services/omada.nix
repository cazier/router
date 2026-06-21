{
  pkgs,
  lib,
  timezone,
  ...
}: let
  _volume_data = {
    data = rec {
      name = "omada_omada-data";
      path = "/opt/tplink/EAPController/data";
      service = "podman-volume-${name}.service";
    };
    logs = rec {
      name = "omada_omada-logs";
      path = "/opt/tplink/EAPController/logs";
      service = "podman-volume-${name}.service";
    };
  };
  volumes = rec {
    data = builtins.attrValues _volume_data;
    mount = map (volume: "${volume.name}:${volume.path}:rw") data;
    services = map (volume: volume.service) data;
  };
in {
  virtualisation.oci-containers = {
    backend = "podman";
    containers.omada-controller = {
      image = "mbentley/omada-controller:6.1";
      environment = {
        TZ = timezone;
        WEB_CONFIG_OVERRIDE = "false";
      };
      volumes = volumes.mount;
      podman.sdnotify = "conmon";
      extraOptions = [
        "--network=host"
      ];
      log-driver = "journald";
    };
  };

  systemd.services =
    {
      podman-omada-controller = {
        after = volumes.services;
        requires = volumes.services;
        serviceConfig.Restart = lib.mkOverride 90 "always";
      };
    }
    // builtins.listToAttrs (map (volume: {
        name = "podman-volume-${volume.name}";
        value = {
          path = [pkgs.podman];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = "podman volume inspect ${volume.name} || podman volume create ${volume.name}";
        };
      })
      volumes.data);
}
