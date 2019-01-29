## ######### PROJECT NAME : ##########
##
## ada_drives.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of ada.pm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Feb 19 16:35:28 2009 Boutonnet Alexandre
## Last update Wed Mar  4 13:01:15 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

# This function returns the drive list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drives_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number PD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drive_number   = -1;
    my $flag_enclosure = 0;    # my anti-enclosure filter :)
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/ +Device \#/
            && $line !~ m/ +Device \#$drive_number/ )
        {
            if ( $drive_number > -1 && $flag_enclosure ) {
                push( @$tab, "d" . $drive_number );
            }
            ($drive_number) = ( $line =~ m/ +Device \#(\d+)/ );
            $flag_enclosure = 0;
        }
        $flag_enclosure = 1 if ( $line =~ m/ +Device is a Hard drive/ );
    }

    return ( 0, $tab );
}

# This function returns the drive information
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drive_info {
    my ( $controller, $drive ) = @_;

    #    my $local_flag_cache = _enable_cache();

    my ( $ret_code, $data ) = get_drives_info($controller);

    #    _disable_cache($local_flag_cache);

    return ( $ret_code, $data ) if ($ret_code);

    return ( 1, "drive not found" ) if ( !exists( $data->{$drive} ) );
    return ( 0, $data->{$drive} );
}

# This function returns an hash containing
# all drives informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drives_info {
    my $controller = shift;

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number PD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $tmp_hash        = {};
    my $drive_number    = -1;
    my $drivestatus     = 'ok';
    my $flag_enclosure  = 0;      # my anti-enclosure filter :)
    my $flag_search_lun = 0;      # flag to active lun state search
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/ +Device \#/
            && $line !~ m/ +Device \#$drive_number/ )
        {
            if ( $drive_number > -1 && $flag_enclosure ) {
                $tmp_hash->{status} =
                  lib_raid_codes::get_drive_status_code($drivestatus);
                $hash->{ 'd' . $drive_number } = $tmp_hash;
                $drivestatus                   = 'ok';
                $tmp_hash                      = {};
            }
            ($drive_number) = ( $line =~ m/ +Device \#(\d+)/ );
            $flag_enclosure  = 0;
            $flag_search_lun = 0;
        }
        $flag_enclosure = 1 if ( $line =~ m/ +Device is a Hard drive/ );

        if ( $line =~ m/ +Reported Location +\:/ ) {

            # Enclosure number
            if ( $line =~ m/ +Reported Location +\: Enclosure/ ) {
                ( $tmp_hash->{enclosurenumber} ) =
                  ( $line =~ m/ +Reported Location +\: Enclosure (\d+),/ );
                $tmp_hash->{connectornumber} = -1;
            } elsif ( $line =~ m/ +Reported Location +\: Connector/ ) {
                ( $tmp_hash->{connectornumber} ) =
                  ( $line =~ m/ +Reported Location +\: Connector (\d+),/ );
                $tmp_hash->{enclosurenumber} = -1;
            }
        }

        # Slot number
        if ( $line =~ m/ +Reported Channel,Device\(T:L\) +\: (\d+,\d+)/ ) {
            $tmp_hash->{slotnumber} = $1;
        } elsif (
            $line =~ m/ +Reported Location +\: Connector (\d+), Device (\d+)/ )
        {

            # with arcconf > V7.00, series 5000
            $tmp_hash->{slotnumber} = "$1,$2";
        } elsif ( $line =~ m/ +Reported Location +\: Enclosure (\d+), (\d+)/ ) {

            # with arcconf > V7.00, series 6000
            $tmp_hash->{slotnumber} = "$1,$2";
        } elsif (
            $line =~ m/ +Reported Location +\: Enclosure (\d+), Slot (\d+)/ )
        {

            # with arcconf > V9.00, series 8000
            $tmp_hash->{slotnumber} = "$1,$2";
        }

        # If I have to found the lun..
        if ( $flag_search_lun and $tmp_hash->{slotnumber} ) {
            my $local_cache_flag = _enable_cache();

            $tmp_hash->{inarray} = '-128';
            my ( $err, $lun ) =
              get_lun_from_drive( $controller, $tmp_hash->{slotnumber} );
            $tmp_hash->{inarray} = $lun if ( !$err );

            _disable_cache($local_cache_flag);
        }

        # Capacity
        if ( $line =~ m/ +Size +\:/ ) {
            ( $tmp_hash->{size} ) = ( $line =~ m/ +Size +\: (\d+) / );

# In MB
# $tmp_hash->{size} = sprintf("%.2f", $tmp_hash->{size} / 1024); # in GB please !
        }

        # Vendor
        ( $tmp_hash->{vendor} ) = ( $line =~ m/ +Vendor +\: (\w+)/ )
          if ( $line =~ m/ +Vendor +/ );

        # model
        ( $tmp_hash->{model} ) = ( $line =~ m/ +Model +\: (.+)/ )
          if ( $line =~ m/ +Model +/ );

        # serial number
        ( $tmp_hash->{serialnumber} ) =
          ( $line =~ m/ +Serial number +\: (\w+)/ )
          if ( $line =~ m/ +Serial number +/ );

        # drive status
        if ( $line =~ m/^ +Failed logical device segments\s*:\s*True/ ) {
            $drivestatus = 'inconsistent';
        }

        if ( $line =~ m/^ +State +/ ) {
            my ($status) = ( $line =~ m/ +State +\: (.+)/ );

            if ( $status =~ m/Hot.Spare/ ) {
                $tmp_hash->{inarray} =
                  lib_raid_codes::get_drive_inarray_code('hotspare');
            } elsif ( $status eq "Ready" ) {
                $tmp_hash->{inarray} =
                  lib_raid_codes::get_drive_inarray_code('unused');
            } elsif ( $status =~ m/Online/ ) {

                # I known that I get the slotnumber in a next loop
                # I put on my lun search flag..
                $flag_search_lun = 1;
            } elsif ( $status eq "Rebuilding" ) {
                $drivestatus = 'rebuilding';

                # I known that I get the slotnumber in a next loop
                # I put on my lun search flag..
                $flag_search_lun = 1;
            } else {
                $drivestatus = 'fail';
                $tmp_hash->{inarray} =
                  lib_raid_codes::get_drive_inarray_code('unused');
            }

        }

        # WWN
        ( $tmp_hash->{WWN} ) = ( $line =~ m/ +World-wide name +\: (\w+)/ )
          if ( $line =~ m/ +World-wide name +/ );

        # Drive type
        $tmp_hash->{type} = lib_raid_codes::get_drive_type_code(
            ( $line =~ m/ +Transfer Speed +\: (.*)/ ) )
          if ( $line =~ m/ +Transfer Speed +/ );

    }

    # store info for the last drive
    if ($flag_enclosure) {
        $tmp_hash->{status} =
          lib_raid_codes::get_drive_status_code($drivestatus);
        $hash->{ 'd' . $drive_number } = $tmp_hash;
        $drivestatus                   = 'ok';
        $tmp_hash                      = {};
    }

    return ( 0, $hash );
}

##### FONCTION NON TERMINEE !!
# # This function returns an array of drives
# # present in the array/lun given in parameter
# # This function takes the controller and
# # the array number in parameter
# # [0] : 0 => Ok, != O => Fail
# # [1] : Ok => int, Fail => error_msg
# sub get_drive_from_array
# {
#     my ($controller, $array) = @_;

#     my ($controller_number) = ($controller =~ m/$CONTROLLER_PREFIX(\d+)/);
#     return (1, "unable to find the controller $controller") if (!defined($controller_number));

#     # getting informations about drives
#     my $cmd = "$ada_cmd getconfig $controller_number PD";
#     my ($ret_code, $data) = _exec_cmd($cmd);
#     return ($ret_code, "unable to get physical informations : $data") if ($ret_code);

#     # splitting my output string in an array
#     my @tmp_tab = split(/\n/, $data);

#     my $drive_number = -1;
#     foreach my $line (@tmp_tab)
#     {
# 	if ($line =~ m/ +Device \#/ &&
# 	    $line !~ m/ +Device \#$drive_number/)
# 	{
# 	    ($drive_number) = ($line =~ m/Logical device number (\d+)/);
# 	}
# 	elsif ($line =~ m/Segment/ && $line =~ m/$slot/)
# 	{
# 	    return (0, $drive_number);
# 	}
#     }
#     return (1, "no lun found for this drive");
# }

1;
