## ######### PROJECT NAME : ##########
##
## 3wa_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of the cw.pm plugin
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Mon Mar  2 16:14:16 2009 Boutonnet Alexandre
## Last update Fri Mar  6 17:11:49 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {
    my $cmd = 'info';

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $return_tab = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^c\d+ / );
        my ($controller) = ( $line =~ m/^(\w+) / );
        push @$return_tab, $CONTROLLER_PREFIX . $controller;
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

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about the controller
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $flag_9650 = 0;

    my $number_of_spares = 0;
    foreach my $line (@tmp_tab) {

        # Model & Vendor
        ( $hash->{model} ) = ( $line =~ m/.+ Model = (.+)/ )
          if ( $line =~ m/.+ Model = / );
        $hash->{vendor} = '3ware';

        # Serial Number
        ( $hash->{serialnumber} ) = ( $line =~ m/.+ Serial Number = (\w+)/ )
          if ( $line =~ m/.+ Serial Number = / );

        # Number of arrays
        ( $hash->{numberofarrays} ) = ( $line =~ m/.+ Active Units = (\d+) / )
          if ( $line =~ m/.+ Active Units = / );
        if ( !defined( $hash->{numberofarrays} )
            && $line =~ m/.+ Number of Units = / )
        {
            ( $hash->{numberofarrays} ) =
              ( $line =~ m/.+ Number of Units = (\d+)/ );
            $flag_9650 = 1;
        }
        $hash->{numberofluns} = $hash->{numberofarrays};

        # spare counter
        $number_of_spares++ if ( $line =~ m/^u\d+ +SPARE +/ );

   # BBU
   # bbu   On           Yes       OK        OK       OK       195    08-Jan-2009
        if ( $line =~ m/^bbu/ ) {
            $hash->{BBU}->{status} = lib_raid_codes::get_state_code(
                ( $line =~ m/^bbu +\w+ +\w+ +(\w+)/ ) );
            ( $hash->{BBU}->{duration} ) = ( $line =~ m/ +(\d+) +/ );
        }
    }
    $hash->{numberofspares} = $number_of_spares;

    # i have to substract spare arrays to active arrays
    $hash->{numberofarrays} -= $hash->{numberofspares} if ($flag_9650);

    $hash->{BBU}->{status} = lib_raid_codes::get_state_code('Not Installed')
      if ( !exists( $hash->{BBU}->{status} ) );
    $hash->{WWN} = 'unknown';

    $hash->{BBU}->{status} == 1 ? $hash->{status} = 2 : $hash->{status} = 0;

    return ( 0, $hash );
}

# This function send the rescan request to the controller
# This function takes the controller and controller data in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => msg, Fail => error_msg
sub rescan_controller {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    my $command = "/$controller_name rescan";

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Rescan failed : $err" ) if ($ret_code);

    return ( 0, "Rescan completed : \n$err" );
}
1;
