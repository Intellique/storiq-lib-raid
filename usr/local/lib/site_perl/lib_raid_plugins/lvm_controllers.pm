## ######### PROJECT NAME : ##########
##
## lvm_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of lvm.pm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Fri Mar  6 17:18:00 2009 Boutonnet Alexandre
## Last update Wed Mar 11 16:58:45 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

my $vgdisplay_path = '/sbin/vgdisplay';
my $lvdisplay_path = '/sbin/lvdisplay';

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {

    chomp($vgdisplay_path);
    chomp($lvdisplay_path);

    return ( 1, 'unable to find lvm controller' ) if ( !-x $vgdisplay_path );
    return ( 1, 'unable to find lvm controller' ) if ( !-x $lvdisplay_path );
    return ( 0, ['lvm'] );
}

# This function returns an hash containing
# all informations about the controller
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controller_info {
    my $controller = shift;

    my $hash = {};

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/^$CONTROLLER_PREFIX$/ );

    # calculating number of arrays
    my $cmd = "$vgdisplay_path -c";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get arrays informations : $data" )
      if ($ret_code);

    my @tmp_tab = split( /\n/, $data );

    my $count_hash = {};
    foreach my $line (@tmp_tab) {
        my ($array_name) = ( $line =~ m/ .(.+):/ );
        $count_hash->{$array_name} = undef;
    }
    $hash->{numberofarrays} = scalar( keys( %{$count_hash} ) );

    # calculating number of luns
    $cmd = "$lvdisplay_path -c";
    ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get luns informations : $data" )
      if ($ret_code);

    @tmp_tab = split( /\n/, $data );

    $count_hash = {};
    foreach my $line (@tmp_tab) {
        my ($lun_name) = ( $line =~ m/ +([\w\/]+)\:/ );
        $count_hash->{$lun_name} = undef;
    }
    $hash->{numberofluns} = scalar( keys( %{$count_hash} ) );

    $hash->{numberofspares} = 0;
    $hash->{BBU}->{status} =
      lib_raid_codes::get_state_code('Not Installed');
    $hash->{WWN}          = 'unknown';
    $hash->{status}       = 0;
    $hash->{model}        = 'lvm2';
    $hash->{serialnumber} = 'none';
    $hash->{vendor}       = 'lvm';

    return ( 0, $hash );
}

1;
