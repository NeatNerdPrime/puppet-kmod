#
# == Definition: kmod::load
#
# Manage a kernel module in /etc/modules.
#
# Parameters:
# - *ensure*: present/absent;
# - *file*: optionally, set the file where the stanza is written. Not
#           used for systems running systemd.
#
# Example usage:
#
#   kmod::load { 'sha256': }
#
define kmod::load (
  $ensure=present,
  $file='/etc/modules',
) {
  case $ensure {
    'present': {
      case $facts['os']['family'] {
        'Debian': {
          $changes = "clear '${name}'"
        }
        'Suse': {
          $changes = "set MODULES_LOADED_ON_BOOT/value[.='${name}'] '${name}'"
        }
        default: {}
      }

      exec { "modprobe ${name}":
        path   => '/bin:/sbin:/usr/bin:/usr/sbin',
        unless => "egrep -q '^${name} ' /proc/modules",
      }
    }

    'absent': {
      case $facts['os']['family'] {
        'Debian': {
          $changes = "rm '${name}'"
        }
        'Suse': {
          $changes = "rm MODULES_LOADED_ON_BOOT/value[.='${name}']"
        }
        default: {}
      }

      exec { "modprobe -r ${name}":
        path   => '/bin:/sbin:/usr/bin:/usr/sbin',
        onlyif => "egrep -q '^${name} ' /proc/modules",
      }
    }

    default: { fail "${module_name}: unknown ensure value ${ensure}" }
  }

  if $facts['service_provider'] == 'systemd' {
    file { "/etc/modules-load.d/${name}.conf":
      ensure  => $ensure,
      mode    => '0644',
      content => "# This file is managed by the puppet kmod module.\n${name}\n",
    }
  } else {
    case $facts['os']['family'] {
      'Debian': {
        augeas { "Manage ${name} in ${file}":
          incl    => $file,
          lens    => 'Modules.lns',
          changes => $changes,
        }
      }
      'RedHat': {
        file { "/etc/sysconfig/modules/${name}.modules":
          ensure  => $ensure,
          mode    => '0755',
          content => template('kmod/redhat.modprobe.erb'),
        }
      }
      'Suse': {
        $kernelfile = $file ? {
          '/etc/modules' => '/etc/sysconfig/kernel',
          default        => $file,
        }
        augeas { "sysconfig_kernel_MODULES_LOADED_ON_BOOT_${name}":
          lens    => 'Shellvars_list.lns',
          incl    => $kernelfile,
          changes => $changes,
        }
      }
      default: {
        fail "${module_name}: Unknown OS family ${facts['os']['family']}"
      }
    }
  }
}
