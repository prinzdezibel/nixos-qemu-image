{
  pkgs,
  ...
}:
{
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      disable_root = false;
      preserve_hostname = false;
    };

    config = ''
      cloud_init_modules:
        - migrator
        - seed_random
        - bootcmd
        - write-files
        - growpart
        - resizefs
        - set_hostname
        - update_hostname
        # - update_etc_hosts
        - resolv_conf
        - ca-certs
        - rsyslog
        - users-groups

      cloud_config_modules:
        - disk_setup
        - mounts
        - ssh-import-id
        # - locale (errors with 'not implemented')
        - set-passwords
        - timezone
        - ntp
        - disable-ec2-metadata
        - runcmd
        - ssh

      cloud_final_modules: 
        #- salt-minion
        - rightscale_userdata
        - scripts-vendor
        - scripts-per-once
        - scripts-per-boot
        - scripts-per-instance
        - scripts-user
        - ssh-authkey-fingerprints
        # - keys-to-console #errors with 'Unable to activate module keys-to-console'
        - phone-home
        - final-message
        - power-state-change

      chpasswd:
        expire: false
      # syslog_fix_perms: root:root
      # mount_default_fields: [~, ~, 'auto', 'defaults', '0', '2']
    '';
  };
}
