## ######### PROJECT NAME : ##########
##
## ddn.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file permits the support of DDN raid controllers.
##
## ###################################
##
## Made by Emmanuel Florac
## Login   <eflorac@intellique.com>
##
##
## ###################################
##

package ddn;
require Lib_Raid::ddn_controllers;

use strict;
use warnings;
use Net::SSH::Expect;

use Lib_Raid::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'ddn';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : on)

# GLOBALS
my $CACHE_HASH = {};

# maximum cache duration in seconds
my $CACHELIMIT = 30;

# configuration object
our $config;


sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

# This function returns all information
# about all controllers
sub get_all_info {
    my $hash = {};

    my ( $ret_code, $controllers ) = get_controllers_list();
    return ( $ret_code, $controllers ) if ($ret_code);

    foreach my $ctl (@$controllers) {
        ( $ret_code, $hash->{$ctl} ) = get_controller_info($ctl);
        return ( $ret_code, $hash->{$ctl} ) if $ret_code;
    }

    return ( 0, $hash );
}

### PRIVATES FUNCTIONS ###
sub _exec_cmd {
    my ( $cmd, $ctl ) = @_;

    my ( $err, $parms ) = _get_config($ctl);
    return ( $err, "no such controller $ctl" ) if $err;

    if (   $CACHE_FLAG
        && exists( $CACHE_HASH->{$ctl}{$cmd} )
        && $CACHE_HASH->{timestamp}{$ctl}{$cmd} > time() )
    {

        # returning data stored in cache
        return ( 0, $CACHE_HASH->{$ctl}{$cmd} );
    }

    my $ssh = Net::SSH::Expect->new(
        host     => $parms->{ip_address},
        password => $parms->{password},
        user     => $parms->{user},
        raw_pty  => 1,
        timeout  => $parms->{timeout},
    );

    my $login_output = $ssh->login();
    if ( $parms->{user} eq "ddn" ) {

        # root login with  shell
        $cmd = qq(echo "$cmd" | /ddn/bin/clui);
    } elsif ( $login_output !~ /RAID\[\d\]\$/ ) {
        return ( -128, "Login failed. Login output was '$login_output'" );
    }

    my $cmdreturn = $ssh->exec($cmd);
    $ssh->close();

    # setting cache
    $CACHE_HASH->{$ctl}{$cmd} = $cmdreturn;
    $CACHE_HASH->{timestamp}{$ctl}{$cmd} = time() + $CACHELIMIT;

    return ( 0, $cmdreturn ) if $cmdreturn;
    return ( 1, "No data" );
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

# should move to LibRaid.pm
sub _get_config {

    my $ctl = shift;
	
    my $err;
	
	if ( not $config ) {
	( $err, $config )= Lib_Raid::load_config();
	    return ( 1, "failed to load config : $config" ) if $err;
	}

    my ( undef, @controllers ) = $config->get_section();

    if ( uc($ctl) ~~ @controllers ) {
        return ( 0, $config->{CONF}{ uc($ctl) } );
    }
    return ( 1, "no such controller $ctl" );
}

1;
