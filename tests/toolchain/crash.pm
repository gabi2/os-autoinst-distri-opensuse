# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    select_console('root-console');

    script_run 'zypper -n in yast2-kdump kdump crash';

    script_run 'yast2 kdump', 0;

    if (check_screen 'yast2-kdump-disabled') {
        send_key 'alt-u';    # enable kdump
    }

    assert_screen 'yast2-kdump-enabled';
    send_key 'alt-o';        # OK

    if (check_screen 'yast2-kdump-restart-info') {
        send_key 'alt-o';    # OK
    }

    # activate kdump
    script_run 'reboot', 0;
    wait_boot;
    select_console 'root-console';

    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        my $arch    = get_var('ARCH');
        my $version = get_var('VERSION');

        assert_script_run "zypper ar -f http://download.suse.de/ibs/SUSE/Products/SLE-SERVER/$version/$arch/product_debug/ SLES-Server-Debug-Pool";
        assert_script_run "zypper ar -f http://download.suse.de/ibs/SUSE/Updates/SLE-SERVER/$version/$arch/update_debug/ SLES-Server-Debug-Updates";

        assert_script_run 'zypper ref; zypper -n -v in kernel-default-base-debuginfo kernel-default-debuginfo', 300;

        script_run 'zypper -n rr SLES-Server-Debug-Pool SLES-Server-Debug-Updates';
    }
    else {
        my $opensuse_debug_repos = 'repo-debug ';
        if (!check_var('VERSION', 'Tumbleweed')) {
            $opensuse_debug_repos .= 'repo-debug-update ';
        }
        assert_script_run "zypper -n mr -e $opensuse_debug_repos";
        assert_script_run 'zypper ref; zypper -n -v in kernel-default-base-debuginfo kernel-default-debuginfo', 300;
        assert_script_run "zypper -n mr -d $opensuse_debug_repos";
    }

    validate_script_output "yast2 kdump show 2>&1", sub { m/Kdump is enabled/ };

    # get dump
    script_run "echo c > /proc/sysrq-trigger", 0;

    # wait for system's reboot
    wait_boot;
    select_console 'root-console';

    my $crash_cmd = 'echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`.gz';
    assert_script_run "$crash_cmd";
    validate_script_output "$crash_cmd", sub { m/PANIC/ };
}

1;
# vim: set sw=4 et:
