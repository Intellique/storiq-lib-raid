## ######### PROJECT NAME : ##########
##
## lvm_arrays.pm for Lib_Raid
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
## Started on  Wed Mar 11 15:59:38 2009 Boutonnet Alexandre
## Last update Mon Mar 23 17:57:06 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

my $vgdisplay_path = '/sbin/vgdisplay';

# This function returns an hash containing
# all arrays informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_arrays_info {
    my $controller = shift;

    my $hash = {};

    my ( $ret_code, $data ) = get_arrays_list($controller);
    return ( $ret_code, $data ) if ($ret_code);

    foreach my $array (@$data) {
        ( $ret_code, $data ) = get_array_info( $controller, $array );
        return ( $ret_code, $data ) if ( $ret_code && $ret_code != 2 );

        $hash->{$array} = $data if ( !$ret_code );
    }
    return ( 0, $hash );
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

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    # getting informations about drives
    my $cmd = "$vgdisplay_path $array";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get array informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {

        # Size
        if ( $line =~ m/VG Size/ ) {
            my ($size) = ( $line =~ m/ +([\d\,\.]+) .+/ );
            $size =~ s/\,/\./;

            if ( $line =~ m/Gi?B/ )    # GB
            {
                $hash->{size} = sprintf( "%.2f", $size * 1024 );
            } elsif ( $line =~ m/Ti?B/ )    # TB
            {
                $hash->{size} = sprintf( "%.2f", $size * ( 1024 * 1024 ) );
            } else                        # others.. maybe MB
            {
                $hash->{size} = $size;
            }
        }
    }

    $hash->{drives} = _get_drives_in_array($array);

    $hash->{status}     = lib_raid_codes::get_state_code('ok');
    $hash->{stripesize} = 'unknown';
    $hash->{raidtype}   = lib_raid_codes::get_raid_level_code('RAID-0');

    return ( 0, $hash );
}

# This function returns the arrays list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_arrays_list {
    my $controller = shift;

    my $tab = ();

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    # getting informations about drives
    my $cmd = "$vgdisplay_path -c";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get arrays informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $arrays_list = ();
    foreach my $line (@tmp_tab) {
        my ($array) = ( $line =~ m/^ +([\w\/]+):/ );
        push( @$arrays_list, $array );
    }
    return ( 0, $arrays_list );
}

sub _get_drives_in_array {
    my $array = shift;

    my $tab = ();

    # getting informations about drives
    my $cmd = 'pvdisplay -c';
    my ( $ret_code, $data ) = _exec_cmd($cmd);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/\:$array\:/ );
        my ($drive) = ( $line =~ m/^ +([\w\/]+):/ );
        push( @$tab, $drive );
    }

    return ($tab);
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

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

# For raid level i check if it's a real raid level
#     return (1, "wrong raid level") if (defined($hash->{raidlevel}) && $hash->{raidlevel} ne "raid0");

    # Physical volume creation
    my $cmd_drive_list = '';
    my $drives_list    = get_drives_list($controller);
    foreach my $drive ( @{ $hash->{drives} } ) {
        $cmd_drive_list .= " $drive";

        next
          if ( grep( /$drive/, @$drives_list ) );    # My drive is already a pv
        my ( $err_code, $err_msg ) = _create_pv($drive);
        return ( $err_code, $err_msg ) if ($err_code);
    }

    my $name = $hash->{name};

    # if user don't give a name
    # I must find one
    if ( !defined($name) ) {
        my $array_list = get_arrays_list($controller);
        my $major      = -1;
        foreach my $array (@$array_list) {
            next if ( $array !~ m/.+\d+$/ );
            my ($tmp_major) = ( $array =~ m/.+(\d+)$/ );
            if ( $tmp_major > $major ) {
                $major = $tmp_major;
            }
        }
        $major++;
        $name = "vg" . $major;
    }

    my $command = "vgcreate $name $cmd_drive_list";

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array creation failed : $err" ) if ($ret_code);

    return ( 0, 'Array creation completed successfully' );
}

sub _create_pv {
    my $drive = shift;

    my $cmd = "pvcreate $drive";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "$data" ) if ($ret_code);

    return ( 0, 0 );
}

sub _delete_pv {
    my $drive = shift;

    my $cmd = "pvremove $drive";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "$data" ) if ($ret_code);

    return ( 0, 0 );
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

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'wrong arrays list' )
      if ( !exists( $hash->{arrays} )
        || !scalar( @{ $hash->{arrays} } ) );

    foreach my $array ( @{ $hash->{arrays} } ) {

        # Seek for pv drives in my array
        my $drive_list = _get_drives_in_array($array);

        my $cmd = "vgremove $array";
        my ( $ret_code, $data ) = _exec_cmd($cmd);
        return ( $ret_code, "$data" ) if ($ret_code);

        # deleting pv..
        foreach my $drive (@$drive_list) {
            my ( $err_code, $err_msg ) = _delete_pv($drive);
            return ( $err_code, $err_msg ) if ($err_code);
        }
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

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'wrong arrays list' )
      if ( !exists( $hash->{arrays} )
        || !scalar( @{ $hash->{arrays} } ) );
    return ( 1, 'wrong drive list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    my $array = shift( @{ $hash->{arrays} } );

    my $cmd_drive_list = '';
    my $drives_list    = _get_drives_in_array($array);
    my $pv_drives_list = get_drives_list($controller);
    foreach my $drive ( @{ $hash->{drives} } ) {
        next if ( grep( /$drive/, @$drives_list ) );

        if (
            !grep( /$drive/, @$pv_drives_list ) ) # My drive is not already a pv
        {
            my ( $err_code, $err_msg ) = _create_pv($drive);
            return ( $err_code, $err_msg ) if ($err_code);
        }

        $cmd_drive_list .= " $drive";
    }

    return ( 1, 'No drives are available to expand this array' )
      if ( $cmd_drive_list eq '' );

    my $command = "vgextend $array $cmd_drive_list";

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array migration failed : $err" ) if ($ret_code);

    return ( 0, 'Array migration started successfully' );
}

1;
