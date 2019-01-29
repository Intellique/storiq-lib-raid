## ######### PROJECT NAME : ##########
##
## ada_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of ca.pm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Feb 19 16:39:43 2009 Boutonnet Alexandre
## Last update Mon Mar  2 16:21:02 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

# This function returns an hash containing
# all informations about the controller
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controller_info {
    my $controller;

    if   ( scalar(@_) == 1 ) { $controller = $_[0] }
    else                     { $controller = $_[1] }

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    _get_adapter_information( $controller_number, $hash );

    $hash->{numberofspares} = 'unknown';
    my ( $ret_code, $data ) = _get_number_of_spare( $controller_number, $hash );
    $hash->{numberofspares} = $data if ( !$ret_code );

    return ( 0, $hash );
}

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {
    my $cmd = "$ada_cmd GETVERSION";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $return_tab = ();
    foreach my $line (@tmp_tab) {
        my ($controller) = ( $line =~ m/Controller \#(\d+)$/ );
        push @$return_tab, $CONTROLLER_PREFIX . $controller if $controller;
    }

    return ( 0, $return_tab );
}

# function to rescan the controllers for new drives
# takes the controller as a parameter
# returns error_code, error_message
sub rescan_controller {
    my ( $obj, $controller ) = @_;

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );

    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    my $cmd = "$ada_cmd RESCAN $controller_number";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to rescan controller : $data" )
      if ($ret_code);

    return ( 0, "Rescan complete." );
}

1;
