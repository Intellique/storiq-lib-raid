## ######### PROJECT NAME : ##########
##
## ada_luns.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of ca.pm package
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Feb 19 15:49:17 2009 Boutonnet Alexandre
## Last update Mon Mar  2 16:21:27 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

# This function returns luns informations
# It take the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_luns_info {
    my $controller = shift;

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number LD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get lun informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $hash;
    my $tmp_hash   = {};
    my $lun_number = -1;
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/Logical [d|D]evice number /
            && $line !~ m/Logical [d|D]evice number $lun_number/ )
        {
            if ( $lun_number > -1 ) {

                # I have to find all arrays depending of this lun
                my $local_cache_flag = _enable_cache();
                $tmp_hash->{arrays} =
                  get_arrays_from_lun( $controller, 'l' . $lun_number );
                _disable_cache($local_cache_flag);

                $hash->{ 'l' . $lun_number } = $tmp_hash;
                $tmp_hash = {};
            }
            ($lun_number) = ( $line =~ m/Logical [d|D]evice number (\d+)/ );
        }

        # Lun Name
        if ( $line =~ m/ +Logical [d|D]evice name +\: (.*)/ ) {
            $tmp_hash->{name} = $1;
			$tmp_hash->{name} =~ s/\s+$//g;
        }

        # Lun Status
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

        # Size
        if ( $line =~ m/^ +Size +\: (\d+)/ ) {
            $tmp_hash->{size} = $1;

# In MB..
# $tmp_hash->{size} = sprintf("%.2f", $tmp_hash->{size} / 1024); # in GB please !
        }
    }

    # I have to find all arrays depending of this lun
    my $local_cache_flag = _enable_cache();
    $tmp_hash->{arrays} = get_arrays_from_lun( $controller, 'l' . $lun_number );
    _disable_cache($local_cache_flag);
    $hash->{ 'l' . $lun_number } = $tmp_hash if ( $lun_number > -1 );

    return ( 0, $hash );
}

# This function returns an hash containing
# all informations about the lun
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_lun_info {
    my ( $controller, $lun ) = @_;

    my ( $ret_code, $data ) = get_luns_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    return ( 1, 'lun not found' ) if ( !exists( $data->{$lun} ) );
    return ( 0, $data->{$lun} );
}

# This function returns an list containing
# all luns name
# This function takes the controller in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_luns_list {
    my ($controller) = @_;

    my ( $ret_code, $data ) = get_luns_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    my $tab = ();
    foreach my $lun ( sort( keys(%$data) ) ) {
        push( @$tab, $lun );
    }
    return ( 0, $tab );
}

# This function returns the number of the lun
# where is located the drive given in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => int, Fail => error_msg
sub get_lun_from_drive {
    my ( $controller, $slot ) = @_;

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number LD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get lun informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $lun_number = -1;
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/Logical [d|D]evice number /
            && $line !~ m/Logical [d|D]evice number $lun_number/ )
        {
            ($lun_number) = ( $line =~ m/Logical [d|D]evice number (\d+)/ );
        } elsif ( $line =~ m/Segment/ && $line =~ m/$slot/ ) {

            # arcconf =< 7.00
            return ( 0, $lun_number );
        } elsif ( $line =~ m/Segment|Device \d+/
            && $line =~ m/Controller:$controller_number,\w+:(\d+),\w+:(\d+)/ )
        {

            # arcconf > 7.00
            my ( $con, $dev ) = ( $1, $2 );
            return ( 0, $lun_number ) if ( $slot eq "$con,$dev" );
        } elsif ( $line =~ m/Segment|Device \d+/
            && $line =~ m/Enclosure:(\d+), Slot:(\d+)/ )
        {
            # arcconf > 9.00, SAS expander
            my ( $enc, $dev ) = ( $1, $2 );
            return ( 0, $lun_number ) if ( $slot eq "$enc,$dev" );
        } elsif ( $line =~ m/Segment|Device \d+/
            && $line =~ m/Connector:(\d+), Device:(\d+)/ )
        {
            # arcconf > 9.00, no SAS expander
            my ( $enc, $dev ) = ( $1, $2 );
            return ( 0, $lun_number ) if ( $slot eq "$enc,$dev" );
        } elsif ( $line =~ m/Segment|Device \d+/
            && $line =~ m/Channel:(\d+), Device:(\d+)/ )
        {
            # arcconf > 9.00, other case
            my ( $enc, $dev ) = ( $1, $2 );
            return ( 0, $lun_number ) if ( $slot eq "$enc,$dev" );
        }

    }
    return ( 1, 'no lun found for this drive' );
}

1;
