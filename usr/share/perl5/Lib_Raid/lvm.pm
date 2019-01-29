## ######### PROJECT NAME : ##########
##
## lvm.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file brings the support of lvm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Fri Mar  6 13:38:53 2009 Boutonnet Alexandre
## Last update Fri Mar 27 17:09:20 2009 Boutonnet Alexandre
##
## ###################################
##

package lvm;
require Lib_Raid::lvm_controllers;
require Lib_Raid::lvm_drives;
require Lib_Raid::lvm_arrays;
require Lib_Raid::lvm_luns;

use strict;
use warnings;
use IPC::Run3;

use Lib_Raid::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'lvm';

sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

# This function returns all information
# about everything :)
sub get_all_info {
    my $hash = {};

    my ( $ret_code, $data ) = get_controllers_list();
    return ( $ret_code, $data ) if ($ret_code);

    my $controller_name = @{$data}[0];

    ( $ret_code, $data ) = get_controller_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name} = $data;

    my $local_cache_flag = _enable_cache();

    ( $ret_code, $data ) = get_drives_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{drives} = $data;

    ( $ret_code, $data ) = get_arrays_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{arrays} = $data;

    ( $ret_code, $data ) = get_luns_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{luns} = $data;

    # 	($ret_code, $data) = get_enclosures_info($controller_name);
    # 	return ($ret_code, $data) if ($ret_code);
    # 	$hash->{$controller_name}->{enclosures} = $data;

    _disable_cache($local_cache_flag);

    return ( 0, $hash );
}

### PRIVATES FUNCTIONS ###

# Commande execution function.
sub _exec_cmd {
    my $cmd = shift;

    my $stdout;
    my $errout;

    #     if ($CACHE_FLAG && exists($CACHE_HASH->{$cmd}))
    #     {
    # 	# returning data stocked in cache
    # 	return(0, $CACHE_HASH->{$cmd});
    #     }

    run3( $cmd, \undef, \$stdout, \$errout );

    if ($?) {
        chomp($errout);
        return ( 1, $errout, $stdout );
    }

    #     # setting cache
    #     $CACHE_HASH->{$cmd} = $stdout;

    return ( 0, $stdout );
}

1;
