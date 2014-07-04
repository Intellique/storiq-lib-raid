## ######### PROJECT NAME : ##########
##
## 3wa_arrays.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of cw.pm plugin.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Mon Mar  2 16:19:17 2009 Boutonnet Alexandre
## Last update Thu Mar 12 12:58:18 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

# This function returns the arrays list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_arrays_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get arrays informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $arrays_list = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^u(\d+) / || $line =~ m/SPARE/ );
        my ($array_number) = ( $line =~ m/^u(\d+) / );
        push( @$arrays_list, "a" . $array_number );
    }
    return ( 0, $arrays_list );
}

# This function returns an hash containing
# all informations about the array
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_array_info {
    my ( $controller, $array ) = @_;

    my $hash = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get array informations : $data" )
      if ($ret_code);

    my ($array_number) = ( $array =~ m/^a(\d+)/ );
    return ( 1, 'unable to find array number' )
      if ( !defined($array_number) );

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^u$array_number/ );
        return ( 2, 'This array/lun is a spare' ) if ( $line =~ m/SPARE/ );
        $hash->{status} = lib_raid_codes::get_state_code(
            $line =~ m/^u\d+ +[\w\-\d]+ +([\w\-]+) +/ );

        ( $hash->{size} ) = ( $line =~ m/.+ +(\w+\.\w+) / );
        $hash->{size} = sprintf( "%.2f", $hash->{size} * 1024 );    # in MB..

        ( $hash->{stripesize} ) = ( $line =~ m/.+ +(\d+)K / );
        $hash->{stripesize} = 'unknown'
          if ( !defined( $hash->{stripesize} ) );    # Bug single drive..
        $hash->{raidtype} = lib_raid_codes::get_raid_level_code(
            $line =~ m/^^u\d+ +([\w\-\d]+) +\w+/ );

        # Init/verify/migrate progression
        my ($progression) =
          ( $line =~ m/^u\d+ +[\w\-\d]+ +\w+ +[\w\-\d]+ +([\w\-\d]+).+/ );
        ( $hash->{progression} ) = $progression
          if ( defined($progression) && $progression ne "-" );

        # Rebuild progression
        if ( !defined( $hash->{progression} ) ) {
            ($progression) = ( $line =~
                  m/^u\d+ +[\w\-\d]+ +[\w\-]+ +([\w\-\d]+).+ +[\w\-\d]+/ );
            ( $hash->{progression} ) = $progression
              if ( defined($progression) && $progression ne "-" );
        }
    }

    # Special loop to get drives in the array
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^p\d+ / || $line !~ m/ +u$array_number +/ );
        my ($drive_number) = ( $line =~ m/^p(\d+) / );
        push( @{ $hash->{drives} }, 'd' . $drive_number );
    }

    return ( 0, $hash );
}

# This function returns an hash containing
# all arrays informations
# It takes the controller name and status in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
# [2] : updated controller status
sub get_arrays_info {
    my $controller = shift;
    my $ctlstatus  = shift;

    my $hash = {};

    my ( $ret_code, $data ) = get_arrays_list($controller);
    return ( $ret_code, $data ) if ($ret_code);

    foreach my $array (@$data) {
        ( $ret_code, $data ) = get_array_info( $controller, $array );
        $ctlstatus = 2 if ( $data->{status} != 0 and $data->{status} != 13 );

        return ( $ret_code, $data ) if ( $ret_code && $ret_code != 2 );

        $hash->{$array} = $data if ( !$ret_code );
    }
    return ( 0, $hash, $ctlstatus );
}

# This function creates an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success, Fail => error_msg
sub create_array {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    # For raid level i check if it's a real raid level
    return ( 1, 'wrong raid level' )
      if ( !defined( $hash->{raidlevel} )
        || $hash->{raidlevel} !~ /^-?\d+/ );

    my $command = "/$controller_name add ";

    my $raidlevel = _get_raid_string( $hash->{raidlevel} );   # no error check !
    $command .= "type=$raidlevel disk=";

    my $flag = 0;
    foreach my $drive ( @{ $hash->{drives} } ) {
        $command .= ":" if ($flag);
        my ($drive_number) = ( $drive =~ m/d(\d+)/ );
        $command .= "$drive_number";
        $flag = 1;
    }
    $command .= " ";

    # setting stripesize
    $command .= 'stripe=' . $hash->{stripesize}
      if ( exists( $hash->{stripesize} )
        && defined( $hash->{stripesize} ) );

    # setting name
    $command .= qq(name="$hash->{name}")
      if ( exists( $hash->{name} ) && defined( $hash->{name} ) );

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array creation failed : $err" ) if ($ret_code);

    return ( 0, "Array creation completed successfully" );
}

# This function deletes an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub delete_array {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    return ( 1, 'wrong arrays list' )
      if ( !exists( $hash->{arrays} )
        || !scalar( @{ $hash->{arrays} } ) );

    foreach my $array ( @{ $hash->{arrays} } ) {
        my ($array_number) = ( $array =~ m/a(\d+)/ );
        my $command = "/$controller_name/u$array_number del quiet";

        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        return ( $ret_code, "Array deletion failed : $err" ) if ($ret_code);
    }

    return ( 0, 'Array deletion completed successfully' );
}

# This function expands an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => msg, Fail => error_msg
sub expand_array {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # For raid level i check if it's a real raid level
    return ( 1, 'wrong raid level' )
      if ( !defined( $hash->{raidlevel} )
        || $hash->{raidlevel} !~ /^-?\d+/ );

    return ( 1, 'wrong arrays list' )
      if ( !exists( $hash->{arrays} )
        || !scalar( @{ $hash->{arrays} } ) );

    my $array = $hash->{arrays}[0];
    ($array) = ( $array =~ m/a(\d+)/ );
    return ( 1, 'unable to get array number' ) if ( !defined($array) );

    my $command = "/$controller_name/u$array migrate ";

    my $raidlevel = _get_raid_string( $hash->{raidlevel} );   # no error check !
    $command .= "type=$raidlevel ";

    if ( defined( $hash->{drives} ) && scalar( @{ $hash->{drives} } ) ) {
        $command .= " disk=";

        my $flag = 0;
        foreach my $drive ( @{ $hash->{drives} } ) {
            $command .= ":" if ($flag);
            my ($drive_number) = ( $drive =~ m/d(\d+)/ );
            $command .= "$drive_number";
            $flag = 1;
        }
    }

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array migration failed : $err" ) if ($ret_code);

    return ( 0, 'Array migration started successfully' );
}

# This function verifies an array (runs verify)
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub verify {
    my ( $obj, $controller, $hash, $message, $error );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    return ( 1, 'You must provide an array.' )
      if ( scalar @{ $hash->{arrays} } == 0 );

    foreach my $array ( @{ $hash->{arrays} } ) {
		($array) = ( $array =~ m/a(\d+)/ );
        my $command = "/$controller_name/u$array start verify";
        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        if ($ret_code) {
            $error += $ret_code;
            $message .= "unable to verify array a$array: $err";
        } else {
            $message .= "Verifying array a$array.\n";
        }

    }

    return ( $error, $message );

}

1;
