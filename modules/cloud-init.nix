{
  pkgs,
  ...
}:
{
  services.cloud-init = {
    enable = true;
    #network.enable = true;
    config = ''
      system_info:
        distro: nixos
        #network:
        #  renderers: [ 'networkd' ]
      #users:
      # - default
      ssh_pwauth: false
      disable_root: false
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
