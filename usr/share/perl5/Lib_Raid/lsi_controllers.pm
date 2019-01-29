## ######### PROJECT NAME : ##########
##
## lsi_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of cl.pm
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
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $lsi_cmd;

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {
    my $cmd = "$lsi_cmd show";

    my ( $ret_code, $data ) = _exec_cmd($cmd);

    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # Getting the number of controllers
    my ($number_ctl) = ( $data =~ m/Number of Controllers = (\d+)/g );

    my $return_tab = ();
    foreach my $num ( 0 .. ( $number_ctl - 1 ) ) {
        push @$return_tab, $CONTROLLER_PREFIX . $num;
    }

    return ( 0, $return_tab );
}

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

    my $cmd = "$lsi_cmd /c$controller_number show";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $has_bbu = 0;

    foreach my $line (@tmp_tab) {

        # Model
        ( $hash->{model} ) = ( $line =~ m/= (.+)$/ )
          if ( $line =~ m/Product Name/ );

        # Serial Number
        ( $hash->{serialnumber} ) = ( $line =~ m/= (.+)$/ )
          if ( $line =~ m/Serial Number/ );

        #count lines to BBU info
        $has_bbu++ if $has_bbu;

        # BBU
        $has_bbu = 1
          if ( $line =~ m/Cachevault_Info/
            && !defined( $hash->{BBU}->{status} ) );

        if ( $has_bbu == 7 ) {
            ( $hash->{BBU}{model}, $hash->{BBU}{status}, $hash->{BBU}{temp} ) =
              ( $line =~ m/^(\w+)\s+(\w+)\s+(\w+)\s+/ );

            $hash->{BBU}{status} =
              lib_raid_codes::get_state_code( $hash->{BBU}{status} );
        }

        # WWN
        ( $hash->{WWN} ) = ( $line =~ m/= (.+)$/ )
          if ( $line =~ m /SAS Address/ );

        # Number of arrays / luns
        if ( $line =~ m /Virtual Drives/ ) {
            ( $hash->{numberofarrays} ) = ( $line =~ m/= (\d+)/ );

            # force to  number
            $hash->{numberofarrays} += 0;
            $hash->{numberofluns} = $hash->{numberofarrays};
        }
    }

    # All misc things not currently handle
    $hash->{status}         = lib_raid_codes::get_state_code('ok');
    $hash->{numberofspares} = 0;
    $hash->{vendor}         = 'BROADCOM';

    return ( 0, $hash );
}

1;
