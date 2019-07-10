## ######### PROJECT NAME : ##########
##
## lvm_drives.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of lvm.pm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Wed Mar 11 11:30:55 2009 Boutonnet Alexandre
## Last update Mon Mar 23 17:57:24 2009 Boutonnet Alexandre
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
    my $hash = {
        'status'          => 0,
        'enclosurenumber' => -1,
        'model'           => 'N/A',
        'slotnumber'      => '-1',
        'type'            => -1,
        'connectornumber' => -1,
        'vendor'          => 'N/A',
    };

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'unable to get drive_number' ) if ( $drive !~ m/\/\w+\/\w+/ );

    # getting informations about the drive
    my $cmd = "pvdisplay $drive";
    my ( $ret_code, $data ) = _exec_cmd($cmd);

    # TODO
    #     return (_get_failed_drive_info($controller, $drive)) if ($ret_code);

    # splitting my output string in an array
    my @drive_tmp_tab = split( /\n/, $data );

    my $seek_for_array = 1;
    foreach my $d_line (@drive_tmp_tab) {
        if ( $d_line =~ m/\-\-\-/ && $d_line =~ m/NEW/ ) {
            $hash->{inarray} =
              lib_raid_codes::get_drive_inarray_code("unused");
            $seek_for_array = 0;
        }

        # In array in case of seek for an array
        ( $hash->{inarray} ) = ( $d_line =~ m/ +(\w+)$/ )
          if ( $seek_for_array && $d_line =~ m/VG Name/ );

        # Size
        if ( $d_line =~ m/PV Size/ ) {
            my ($size) = ( $d_line =~ m/ +([\d\,\.]+) .+/ );
            $size =~ s/\,/\./;

            if ( $d_line =~ m/Gi?B/ )    # GB
            {
                $hash->{size} = sprintf( "%.2f", $size * 1024 );
            } elsif ( $d_line =~ m/Ti?B/ )    # TB
            {
                $hash->{size} = sprintf( "%.2f", $size * ( 1024 * 1024 ) );
            } else                          # others.. maybe MB
            {
                $hash->{size} = $size;
            }
        }

        # serial
        ( $hash->{serial} ) = ( $d_line =~ m/ +([\w\-]+)$/ )
          if ( $d_line =~ m/PV UUID/ );

        # model
        # TODO should check for symlinks, etc
        my ($base_device) = ( $drive =~ m#^/dev/([a-z]+)\d*# );

        my %tmphash;
        for my $prop (qw( vendor model )) {
            open my $fv, '<', "/sys/block/$base_device/device/$prop"
              or next;
            $tmphash{$prop} = <$fv>;
            chomp $tmphash{$prop};
            $tmphash{$prop} =~ s/\s+//g;
            close $fv;
        }

        $hash->{vendor} = $tmphash{vendor} if $tmphash{vendor};
        $hash->{model} = $tmphash{model} if $tmphash{model};
    }
    return ( 0, $hash );
}

# This function returns the drive list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drives_list {
    my $controller = shift;

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    # getting informations about drives
    my $cmd = 'pvdisplay -c';
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drives_list = ();
    foreach my $line (@tmp_tab) {
        my ($drive) = ( $line =~ m/^ +([\w\/]+):/ );
        push( @$drives_list, $drive );
    }

    return ( 0, $drives_list );
}

1;
