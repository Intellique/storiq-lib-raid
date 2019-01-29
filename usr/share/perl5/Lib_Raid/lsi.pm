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
## Made by Emmanuel Florac
## Email   <dev@intellique.com>
##
## Started on  Tue Mar 24 17:44:28 2009 Boutonnet Alexandre
##
## ###################################
##

package lsi;
require Lib_Raid::lsi_controllers;
require Lib_Raid::lsi_arrays;
require Lib_Raid::lsi_luns;
require Lib_Raid::lsi_drives;
require Lib_Raid::lsi_enclosures;

use strict;
use warnings;
use IPC::Run3;

use Lib_Raid::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'lsi';
our $lsi_cmd           = '/usr/sbin/storcli';

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
		my @count=keys %{$hash->{$controller_name}{arrays}};
		$hash->{$controller_name}{numberofarrays} = scalar(keys %{$hash->{$controller_name}{arrays}});

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
