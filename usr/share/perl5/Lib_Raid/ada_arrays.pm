## ######### PROJECT NAME : ##########
##
## ada_arrays.pm for Lib_Raid
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
## Started on  Thu Feb 19 17:20:50 2009 Boutonnet Alexandre
## Last update Thu Mar  5 11:30:16 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

# This function returns arrays informations
# It take the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_arrays_info {
    my ($controller) = @_;

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number LD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get array informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $hash;
    my $tmp_hash = {};
    $tmp_hash->{drives} = ();
    my $lun_number = -1;
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/Logical [d|D]evice number /
            && $line !~ m/Logical [d|D]evice number $lun_number/ )
        {
            if ( $lun_number > -1 ) {
                $hash->{ 'a' . $lun_number } = $tmp_hash;
                $tmp_hash                    = {};
                $tmp_hash->{drives}          = ();
            }
            ($lun_number) = ( $line =~ m/Logical [d|D]evice number (\d+)/ );
        }

        # Raid Type

        if ( $line =~ m/ +RAID level +/ ) {
            ( $tmp_hash->{raidtype} ) =
              ( $line =~ m/ +RAID level +\: (\d+E*|Simple_volume)/ );
            $tmp_hash->{raidtype} =
              lib_raid_codes::get_raid_level_code( $tmp_hash->{raidtype} );
        }

        # Stripe size
        ( $tmp_hash->{stripesize} ) =
          ( $line =~ m/ +Stripe-unit size +\: (\d+)/ )
          if ( $line =~ m/ +Stripe-unit size +/ );

        # Size
        if ( $line =~ m/ +Size +/ ) {
            ( $tmp_hash->{size} ) = ( $line =~ m/ +Size +\: (\d+)/ );
        }

        # Array Status
        if ( $line =~ m/ +Status of logical device +\: (.*)/i ) {
            my $status_string = $1;
            my ( $err_code, $progression );

            # arcconf v9 doesn't have stable STATUS!
            # Impacted ( Build/Verify with fix : 31 % )

            if ( $status_string =~ /Impacted/ ) {
                $status_string = 'Impacted';
            }

            $tmp_hash->{status} =
              lib_raid_codes::get_state_code($status_string);

            ( $err_code, $status_string, $progression ) =
              _get_lun_status( $controller_number, $lun_number );

            my $taskstatus = lib_raid_codes::get_state_code($status_string);

        # if the array is in build/verify but OK, it's verify, else it's rebuild
            if ( $tmp_hash->{status} ) {

                # not optimal
                if ( $taskstatus != -1 ) {
                    $tmp_hash->{status}      = 5;              # rebuild
                    $tmp_hash->{progression} = $progression;
                }
            } else {

                # optimal
                if ( $taskstatus != -1 ) {
                    $tmp_hash->{status}      = 13;             # verify
                    $tmp_hash->{progression} = $progression;
                }
            }
        }

        # Drive number
        if ( $line =~ m/Segment/ && $line !~ m/Missing/ ) {
            my ($channel) = ( $line =~ m/.+: \w+ \((.+)\).+/ );

            my ( $err, $data );
            if ( $channel =~ /Connector:(\d+),\s*Device:(\d+)/ ) {

                # case arcconf > 7.00 : reports connector:device (5000)
                # reports enclosure, slot (6000)
                $channel = "Connector $1, Device $2";
                ( $err, $data ) =
                  _get_drive_conn_number( $controller_number, $channel );

            } elsif ( $channel =~ /Enclosure:(\d+),\s*Slot:(\d+)/ ) {

                # case arcconf > 7.00 : reports enclosure, slot (6000)
                $channel = "Enclosure $1, Slot $2";
                ( $err, $data ) =
                  _get_drive_conn_number( $controller_number, $channel );
                  
            } elsif ($channel =~ /Channel:(\d+),\s*Device:(\d+)/) {
				 # case arcconf > 9.00 :  reports Channel, device (8000)
				 $channel = "$1,$2";
				 ( $err, $data ) =
                  _get_drive_number( $controller_number, $channel );

            } else {

                # case arcconf =< 7.00 : reports channel,device
                ( $err, $data ) =
                  _get_drive_number( $controller_number, $channel );
            }

            if ($err) {
                push( @{ $tmp_hash->{drives} }, "d?" );
            } else {
                push( @{ $tmp_hash->{drives} }, "d" . $data );
            }

        }
    }
    $hash->{ 'a' . $lun_number } = $tmp_hash if ( $lun_number > -1 );

    return ( 0, $hash );
}

# This function returns an hash containing
# all informations about the array
# given in parameter
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_array_info {
    my ( $controller, $array ) = @_;

    my ( $ret_code, $data ) = get_arrays_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    return ( 1, 'array not found.' ) if ( !exists( $data->{$array} ) );
    return ( 0, $data->{$array} );
}

# This function returns a list containing
# all arrays name
# This function takes the controller in parameter
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => list, Fail => error_msg
sub get_arrays_list {
    my ($controller) = @_;

    my ( $ret_code, $data ) = get_arrays_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    my $tab = ();
    foreach my $array ( sort( keys(%$data) ) ) {
        push( @$tab, $array );
    }
    return ( 0, $tab );
}

# This function returns a list containing
# all arrays depending of a lun (given in
# parameters)
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => list, Fail => error_msg
sub get_arrays_from_lun {
    my ( $controller, $lun ) = @_;

    my $tab = ();

    my ( $ret_code, $data ) = get_arrays_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    my ($minor_number) = ( $lun =~ m/l(\d+)/ );
    return ( 1, 'unable to find lun number' ) if ( !defined($minor_number) );

    if ( exists( $data->{ "a" . $minor_number } ) ) {
        push( @$tab, "a" . $minor_number );
    } else {
        return ( 1, 'unable to find corresponding arrays' );
    }
    return ( 0, $tab );
}

# This function creates an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => 0, Fail => error_msg
sub create_array {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    # For raid level i check if it's a real raid level
    return ( 1, "wrong raid level." )
      if ( !defined( $hash->{raidlevel} )
        or $hash->{raidlevel} !~ /^-?\d+/ );

    # I get drives list..
    my $hash_drives = get_drives_info($controller);

    my $command = "$ada_cmd create $controller_number logicaldrive ";

    # setting stripesize
    $command .= "stripesize $hash->{stripesize} "
      if ( exists( $hash->{stripesize} )
        && defined( $hash->{stripesize} ) );

    # setting name
    $command .= "name $hash->{name} "
      if ( exists( $hash->{name} ) && defined( $hash->{name} ) );

    # currently we only make arrays spanning whole drives
    # we could add a --size parameter.
    $command .= 'max ';

    # raid_level
    $hash->{raidlevel} = 'volume' if $hash->{raidlevel} < 0;

    $command .= "$hash->{raidlevel} ";

    foreach my $drive ( @{ $hash->{drives} } ) {
        return ( 1, "Drive $drive is not found" )
          if ( !exists( $hash_drives->{$drive} ) );
        return ( 1, "Drive $drive is not ready to be used in an new array" )
          if ( $hash_drives->{$drive}->{inarray} !=
            lib_raid_codes::get_drive_inarray_code('unused') );
        my ( $channel, $id ) =
          ( $hash_drives->{$drive}->{slotnumber} =~ m/(\d+),(\d+)/ );
        $command .= "$channel $id ";
    }

    $command .= 'noprompt';

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array creation failed : $norm" ) if ($ret_code);

    return ( 0, 'Array creation completed successfully' );
}

# This function verifies an array (runs verify_fix)
# If one array member is in error, it verifies it instead.
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub verify {
    my ( $obj, $controller, $hash, $message, $error );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    return ( 1, 'You must provide an array.' )
      if ( scalar @{ $hash->{arrays} } == 0 );

    foreach my $array ( @{ $hash->{arrays} } ) {
        my ( $ret_code, $array_info ) = get_array_info( $controller, $array );
        if ($ret_code) {
            $error += $ret_code;
            $message .= "$array : $array_info\n";
            next;
        }

        if ( $array_info->{status} == 13 or $array_info->{status} == 4 ) {
            $message .= "Array $array is already rebuilding/verifying.\n";
            next;
        }

        if ( $array_info->{status} == 2 ) {

            # start verifying all faulty drives
            foreach my $drive ( @{ $array_info->{drives} } ) {
                my ( $ret_code, $driveinfo ) =
                  get_drive_info( $controller, $drive );
                if ($ret_code) {
                    $error += $ret_code;
                    $message .= "$driveinfo\n";
                }

                if ( $driveinfo->{status} ) {

                    # this drive has a problem
                    my ( $channel, $id ) =
                      ( $driveinfo->{slotnumber} =~ m/(\d+),(\d+)/ );

                    my $cmd =
"$ada_cmd TASK START $controller_number DEVICE $channel $id verify_fix noprompt";
                    my ( $ret_code, $data ) = _exec_cmd($cmd);
                    if ($ret_code) {
                        $error += $ret_code;
                        $message .= "unable to verify drive $drive: $data";
                    } else {
                        $message .= "Verifying drive $drive.\n";
                    }

                }

            }
        } else {
            my ($array_number) = ( $hash->{arrays}[0] =~ m/a(\d+)/ );
            my $cmd =
"$ada_cmd TASK START $controller_number LOGICALDRIVE $array_number verify_fix noprompt";
            my ( $ret_code, $data ) = _exec_cmd($cmd);

            if ($ret_code) {
                $error += $ret_code;
                $message .= "unable to verify array : $data";
            } else {
                $message .= "Verifying array $array.\n";
            }

        }
    }
    return ( 0, $message );
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

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    return ( 1, 'wrong array list.' ) if ( scalar @{ $hash->{arrays} } == 0 );

    my $command = "$ada_cmd delete $controller_number logicaldrive ";

    foreach my $array ( @{ $hash->{arrays} } ) {
        if ( my ($array_number) = ( $array =~ m/a(\d+)/ ) ) {
            $command .= "$array_number ";
        } else {
            return ( 1, "invalid array name '$array'" );
        }
    }

    $command .= 'noprompt';

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array deletion failed : $norm" ) if ($ret_code);

    return ( 0, 'Array deletion completed successfully' );
}

1;
