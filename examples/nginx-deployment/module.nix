{ config, lib, pkgs, test, kubenix, ... }:

with lib;

let
  nginx = pkgs.callPackage ./image.nix {  };
in {
  imports = [ kubenix.module ];

  docker.images.nginx.image = nginx;

  kubernetes.api.deployments.nginx = {
    spec = {
      replicas = 10;
      selector.matchLabels.app = "nginx";
      template = {
        metadata.labels.app = "nginx";
        spec = {
          securityContext.fsGroup = 1000;
          containers.nginx = {
            image = config.docker.images.nginx.path;
            imagePullPolicy = "IfNotPresent";
            volumeMounts."/etc/nginx".name = "config";
            volumeMounts."/var/lib/html".name = "static";
          };
          volumes.config.persistentVolumeClaim.claimName = "config";
          volumes.static.persistentVolumeClaim.claimName = "static";
        };
      };
    };
  };

  kubernetes.api.configmaps.nginx-config.data."nginx.conf" = ''
    user nginx nginx;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;
    events {}
    http {
      access_log /dev/stdout;
      server {
        listen 80;
        index index.html;
        location / {
          root /var/lib/html;
        }
      }
    }
  '';

  kubernetes.api.configmaps.nginx-static.data."index.html" = ''
    <html><body><h1>Hello from NGINX</h1></body></html>
  '';

  kubernetes.api.services.nginx = {
    spec = {
      ports = [{
        name = "http";
        port = 80;
      }];
      selector.app = "nginx";
    };
  };
}
