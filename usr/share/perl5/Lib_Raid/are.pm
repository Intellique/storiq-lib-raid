## ######### PROJECT NAME : ##########
##
## are.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file provides support for areca raid controllers.
##
## ###################################
##
## Made by Emmanuel Florac
## Login   <eflorac@intellique.com>
##
##
## ###################################
##

package are;

# require Lib_Raid::are_luns;
require Lib_Raid::are_drives;
require Lib_Raid::are_controllers;
require Lib_Raid::are_arrays;

# require Lib_Raid::are_enclosures;
# require Lib_Raid::are_spares;

use strict;
use warnings;
use IPC::Run3;

use Lib_Raid::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'are';
our $are_cmd           = '/usr/sbin/arc_cli';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : off)

# GLOBALS
my $CACHE_HASH = {};

# maximum cache duration in seconds
my $CACHELIMIT = 30;

sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

#cache array name to id map;
our $arrayname_to_id = {};

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

        ( $ret_code, $data ) = get_arrays_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}{arrays} = $data->{arrays};
        $hash->{$controller_name}{numberofarrays} =
          scalar( keys %{ $hash->{$controller_name}->{arrays} } );

        $hash->{$controller_name}{luns} = $data->{luns};
        $hash->{$controller_name}{numberofluns} =
          scalar( keys %{ $hash->{$controller_name}->{luns} } );

        ( $ret_code, $data ) = get_drives_info($controller_name);

        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{drives} = $data;

        foreach my $drive ( keys %$data ) {
            if ( $data->{$drive}{inarray} == -2 ) {
                $hash->{$controller_name}{numberofspares}++;
                $hash->{$controller_name}{drives}{$drive}{status} =
                  $hash->{$controller_name}{status};
            } elsif ( $data->{$drive}{inarray} =~ m/(\d+)/ ) {
                push @{ $hash->{$controller_name}{arrays}{ "a" . $1 }{drives} },
                  $drive;
                $hash->{$controller_name}{drives}{$drive}{status} =
                  $hash->{$controller_name}{arrays}{ "a" . $1 }{status};
            }
            $hash->{$controller_name}{enclosures}
              { 'e' . $data->{$drive}{enclosurenumber} } =
              { model => 'Unknown', vendor => 'Unknown' };
        }

        _disable_cache($local_cache_flag);
    }

    return ( 0, $hash );
}

### PRIVATES FUNCTIONS ###

# Commande execution function.
sub _exec_cmd {
    my $cmd   = shift;
    my @input = @_;      # array of commands

    my $cmdid = $cmd . join( '', @input );

    my $stdout;
    my $errout;

    if (   $CACHE_FLAG
        && exists( $CACHE_HASH->{$cmdid} )
        && $CACHE_HASH->{timestamp}{$cmdid} > time() )
    {

        # returning data stored in cache
        return ( 0, $CACHE_HASH->{$cmdid} );
    }

    run3( $cmd, \@input, \$stdout, \$errout );

    my $cli_code = 0;
    $cli_code++ while ( $stdout =~ m/GuiErrMsg<0x00>: Success/g );

    if ( $cli_code < $#input ) {
        chomp($errout);
        return ( 1, $errout, $stdout );
    }

    # setting cache
    $CACHE_HASH->{$cmdid} = $stdout;
    $CACHE_HASH->{timestamp}{$cmdid} = time() + $CACHELIMIT;

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
