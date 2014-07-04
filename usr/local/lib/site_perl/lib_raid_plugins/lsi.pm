## ######### PROJECT NAME : ##########
##
## lsi.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file brings the support of LSI/PERC (MegaCli) Raid card.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Tue Mar 24 12:08:34 2009 Boutonnet Alexandre
## Last update Fri Mar 27 17:10:05 2009 Boutonnet Alexandre
##
## ###################################
##

package lsi;
require "lib_raid_plugins/lsi_controllers.pm";
require "lib_raid_plugins/lsi_arrays.pm";
require "lib_raid_plugins/lsi_luns.pm";
require "lib_raid_plugins/lsi_drives.pm";
require "lib_raid_plugins/lsi_enclosures.pm";

use strict;
use warnings;
use IPC::Run3;

use lib_raid_plugins::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'lsi';
our $lsi_cmd           = '/usr/sbin/MegaCli';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : off)

# GLOBALS
my $CACHE_HASH = {};

# maximum cache duration in seconds
my $CACHELIMIT = 30;

sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

# This function returns all informations
# about everythings :)
sub get_all_info {
    my $hash = {};

    my ( $ret_code, $data ) = get_controllers_list();
    return ( $ret_code, $data ) if ($ret_code);

    my $tab_controllers = $data;
    foreach my $controller_name (@$tab_controllers) {
        ( $ret_code, $data ) = get_controller_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name} = $data;

        my $local_cache_flag = _enable_cache();

        ( $ret_code, $data ) = get_drives_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{drives} = $data;

        ( $ret_code, $data ) = get_luns_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{luns} = $data;

        ( $ret_code, $data ) = get_arrays_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{arrays} = $data;

        ( $ret_code, $data ) = get_enclosures_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{enclosures} = $data;

        _disable_cache($local_cache_flag);
    }

    return ( 0, $hash );
}

### PRIVATES FUNCTIONS ###

# Commande execution function.
sub _exec_cmd {
    my $cmd = shift;

    my $stdout;
    my $errout;

    if (   $CACHE_FLAG
        && exists( $CACHE_HASH->{$cmd} )
        && $CACHE_HASH->{timestamp}{$cmd} > time() )
    {

        # returning data stocked in cache
        return ( 0, $CACHE_HASH->{$cmd} );
    }

    run3( $cmd, \undef, \$stdout, \$errout );

    if ($?) {
        chomp($errout);
        return ( 1, $errout, $stdout );
    }

    # setting cache
    $CACHE_HASH->{$cmd} = $stdout;
    $CACHE_HASH->{timestamp}{$cmd} = time() + $CACHELIMIT;

    return ( 0, $stdout );
}

sub _enable_cache {
    my $flag = shift;

    if ( defined($flag) ) {
        $CACHE_FLAG = 1 if ($flag);
        return 0;
    }
    if ( !$CACHE_FLAG ) {
        $CACHE_FLAG = 1;
        return 1;
    }
    return 0;
}

sub _disable_cache {
    my $flag = shift;

    if ( defined($flag) ) {
        $CACHE_FLAG = 0 if ($flag);
        return 0;
    }
    if ($CACHE_FLAG) {
        $CACHE_FLAG = 0;
        return 1;
    }
    return 0;
}

1;
