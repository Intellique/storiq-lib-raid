## ######### PROJECT NAME : ##########
##
## 3wa_drives.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of cw.pm plugin
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Mon Mar  2 16:16:59 2009 Boutonnet Alexandre
## Last update Fri Mar  6 15:57:33 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

# This function returns an hash containing
# all drives informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drives_info {
    my $controller = shift;

    my $hash = {};

    my ( $ret_code, $data ) = get_drives_list($controller);
    return ( $ret_code, $data ) if ($ret_code);

    foreach my $drive (@$data) {

       #         print
       # "\r                                                                \r";
       #         print "\rGetting information from $controller, $drive...";

        ( $ret_code, $data ) = get_drive_info( $controller, $drive );
        return ( $ret_code, $data ) if ($ret_code);

        $hash->{$drive} = $data;
    }
    return ( 0, $hash );
}

# This function returns an hash containing
# all informations about the drive given in
# parameter. Controller name had to be given too.
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drive_info {
    my ( $controller, $drive ) = @_;
    my $hash = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    my ($drive_number) = ( $drive =~ m/^d(\d+)/ );
    return ( 1, 'unable to get drive_number' ) if ( !defined($drive_number) );

    # getting informations about the drive
    my $cmd = "/$controller_name/p$drive_number show status model capacity";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( _get_failed_drive_info( $controller, $drive ) ) if ($ret_code);

    # splitting my output string in an array
    my @drive_tmp_tab = split( /\n/, $data );

    my $drive_type = '';
    foreach my $d_line (@drive_tmp_tab) {
        next if ( $d_line !~ m/^\/$controller_name\/p$drive_number / );

        # Status
        $hash->{status} = lib_raid_codes::get_drive_status_code(
            ( $d_line =~ m/ Status = ([\w\-]+)/ ) )
          if ( $d_line =~ m/\d+ Status =/ );

        # model & vendor
        if ( $d_line =~ m/ Model / ) {
            ( $hash->{vendor} ) = ( $d_line =~ m/Model = (\w+) / );
            ( $hash->{model} )  = ( $d_line =~ m/Model = \w+ (.*)/ );
            ( $hash->{model} )  = ( $d_line =~ m/Model = (\w+)/ )
              if ( !defined( $hash->{model} ) );
        }

        # size
        ( $hash->{size} ) = ( $d_line =~ m/ Capacity = (.+) .. \(.+/ )
          if ( $d_line =~ m/ Capacity = .+ / );
        if ( $d_line =~ m/ Capacity = .+ TB/ ) {
            $hash->{size} =
              sprintf( "%.2f", $hash->{size} * ( 1024 * 1024 ) )
              ;    # in MB please !
        } elsif ( $d_line =~ m/ Capacity = .+ GB/ ) {
            $hash->{size} =
              sprintf( "%.2f", $hash->{size} * 1024 );    # in MB please !
        }

        # serial
        ( $hash->{serial} ) = ( $d_line =~ m/ Serial = (\w+)/ )
          if ( $d_line =~ m/ Serial = / );

        # WWN (9690 only)
        ( $hash->{WWN} ) = ( $d_line =~ m/ WWN = (\w+)/ )
          if ( $d_line =~ m/ WWN = / );

        # drive_type (9690 only)
        ($drive_type) = ( $d_line =~ m/ Drive Type = (\w+)/ )
          if ( $d_line =~ m/ Drive Type = / );

        # drive_type
        if ( $d_line =~ m/ Link Speed = / ) {
            my ($speed) = ( $d_line =~ m/ Link Speed = (.+)/ );
            $hash->{type} =
              lib_raid_codes::get_drive_type_code( $drive_type . ' ' . $speed );
        }

        # connector number : chai pas encore comment le gerer
        $hash->{connectornumber} = "-1";

        # slot number : chai pas encore comment le gerer
        $hash->{slotnumber} = "-1";
    }

# smart health (basic) IS IT USEFUL? deactivated because only available on 3ware
#         ( $hash->{smartstatus} ) = grep {s/^.*test result: (\w+).*$/$1/}
#             qx|smartctl -H -d 3ware,$drive_number /dev/twa0|;
#         chomp $hash->{smartstatus};

    _get_drive_extra_info( $controller_name, $drive_number, $hash );
    return ( 0, $hash );
}

# This function returns the drive list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drives_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drives_list = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^p(\d+) / );
		next if ( $line =~ m/NOT-PRESENT/ );
		
        my ($drive_number) = ( $line =~ m/^p(\d+) / );
        push( @$drives_list, "d" . $drive_number );
    }
    return ( 0, $drives_list );
}

sub _get_failed_drive_info {
    my ( $controller, $drive ) = @_;
    my $hash = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    my ($drive_number) = ( $drive =~ m/^d(\d+)/ );
    return ( 1, 'unable to get drive_number' ) if ( !defined($drive_number) );

    # getting informations about the drive
    my $cmd = "/$controller_name/p$drive_number show";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, $data ) if ($ret_code);

    # splitting my output string in an array
    my @drive_tmp_tab = split( /\n/, $data );

    my $drive_type = '';
    foreach my $d_line (@drive_tmp_tab) {
        next if ( $d_line !~ m/p\d+/ );
        if ( $d_line =~ m/NOT-PRESENT/ ) {
            $hash->{status} =
              lib_raid_codes::get_drive_status_code('NOT-PRESENT');
        } else {
            $hash->{status} =
              lib_raid_codes::get_drive_status_code('unknown');
        }
        $hash->{model}           = 'N/A';
        $hash->{enclosurenumber} = -1;
        $hash->{size}            = 0;
        $hash->{serialnumber}    = 'N/A';
        $hash->{inarray}         = -128;
        $hash->{type}            = -128;
        $hash->{connectornumber} = -1;
        $hash->{vendor}          = 'N/A';
        $hash->{WWN}             = 'N/A';
    }
    return ( 0, $hash );
}
1;
