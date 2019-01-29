## ######### PROJECT NAME : ##########
##
## are_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of are.pm
##
## ###################################
##
## Made by Emmanuel Florac
## Login   <eflorac@intellique.com>
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $are_cmd;

# This function returns an hash containing
# all informations about the controller
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controller_info {
    my $ctl_name = shift;

    my $cmd = "$are_cmd main";

    my $ctl_model = "Unknown";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $ctlinfo = {};
    foreach my $line (@tmp_tab) {
        my $ctlnum;
        ( $ctlnum, $ctl_model ) =
          ( $line =~ m/^\[?.?\]?\s+(\d+)\s+([\w\-]+)\s+Raid Controller\s+/ );

        if ( $ctlnum and $ctl_name eq $CONTROLLER_PREFIX . $ctlnum ) {
            $ctlinfo->{vendor}         = 'Areca';
            $ctlinfo->{model}          = $ctl_model;
            $ctlinfo->{numberofspares} = -1;
            $ctlinfo->{numberofarrays} = -1;
            $ctlinfo->{numberofluns}   = -1;
        }
    }

#     my ( $ret_code, $data ) = _get_number_of_spare( $ctl_name_number, $hash );
#     $hash->{numberofspares} = $data if ( !$ret_code );

    return ( 0, $ctlinfo );
}

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {
    my $cmd = "$are_cmd main";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $return_tab = ();
    foreach my $line (@tmp_tab) {
        my ($controller) =
          ( $line =~ m/^\[?.?\]?\s+(\d+)\s+[\w\-]+\s+Raid Controller\s+/ );
        push @$return_tab, $CONTROLLER_PREFIX . $controller if $controller;
    }

    return ( 0, $return_tab );
}

1;
