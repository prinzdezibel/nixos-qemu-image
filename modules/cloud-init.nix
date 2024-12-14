{
  pkgs,
  ...
}:
{
  services.cloud-init = {
    enable = true;
    config = ''
      cloud_init_modules:
        - migrator
        - bootcmd
        - write-files
        - growpart
        - resizefs
        - disk_setup
        - mounts
        - set_hostname
        - update_hostname
        # - update_etc_hosts
        - ca-certs
        - rsyslog
        - users-groups

      cloud_config_modules:
        # - locale (errors with 'not implemented')
        - set-passwords
        - timezone
        - resolv_conf
        - ntp
        - disable-ec2-metadata
        - ssh
        - runcmd

      cloud_final_modules: 
        - salt-minion
        #- rightscale_userdata
        - scripts-vendor
        - scripts-per-once
        - scripts-per-boot
        - scripts-per-instance
        - scripts-user
        #- ssh-authkey-fingerprints
        #- keys-to-console
        - phone-home
        - final-message
        - power-state-change

      system_info:
        distro: nixos
        #paths:
        #  cloud_dir: /var/lib/cloud/
        #  templates_dir: /etc/cloud/templates/
        # ssh_svcname: sshd
        #network:
        #  config: disabled
        #  renderers: [ 'network-manager' ]
      ssh_pwauth: false
      disable_root: false
      chpasswd:
        expire: false
      preserve_hostname: false
      syslog_fix_perms: root:root
      # mount_default_fields: [~, ~, 'auto', 'defaults', '0', '2']
    '';
  };
}
