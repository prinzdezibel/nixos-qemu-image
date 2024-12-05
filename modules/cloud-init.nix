{
  pkgs,
  ...
}:
{
  services.cloud-init = {
    enable = false;
    network.enable = true;
    config = ''
      system_info:
        distro: nixos
        network:
          renderers: [ 'networkd' ]
      users:
          - default
      #ssh_pwauth: false
      chpasswd:
        expire: false
      cloud_init_modules:
        - migrator
        - seed_random
        - growpart
        - resizefs
      cloud_config_modules:
        - disk_setup
        - mounts
        - set-passwords
        - ssh
      cloud_final_modules: []
    '';
  };
}
