## ######### PROJECT NAME : ##########
##
## lvm_luns.pm for Lib_Raid
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
## Started on  Wed Mar 11 17:23:39 2009 Boutonnet Alexandre
## Last update Mon Mar 23 17:57:37 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

my $lvdisplay_path = '/sbin/lvdisplay';

# This function returns an hash containing
# all luns informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_luns_info {
    my $controller = shift;

    my $hash = {};

    my ( $ret_code, $data ) = get_luns_list($controller);
    return ( $ret_code, $data ) if ($ret_code);

    foreach my $lun (@$data) {
        ( $ret_code, $data ) = get_lun_info( $controller, $lun );
        return ( $ret_code, $data ) if ( $ret_code && $ret_code != 2 );

        $hash->{$lun} = $data if ( !$ret_code );
    }
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

    my $hash = {};

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    # getting informations about drives
    my $cmd = "$lvdisplay_path $lun";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get lun informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {

        # Size
        if ( $line =~ m/LV Size/ ) {
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

        # Arrays
        if ( $line =~ m/VG Name/ ) {
            push( @{ $hash->{arrays} }, ( $line =~ m/ +(\w+)$/ ) );
        }
    }
    $hash->{status} = lib_raid_codes::get_state_code('ok');
    ( $hash->{name} ) = ( $lun =~ m/\/.+\/.+\/(.+)$/ );

    return ( 0, $hash );
}

# This function returns the lun list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_luns_list {
    my $controller = shift;

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    # getting informations about drives
    my $cmd = "$lvdisplay_path -c";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get luns informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $luns_list = ();
    foreach my $line (@tmp_tab) {
        my ($lun) = ( $line =~ m/^ +([\w\/]+):/ );
        push( @$luns_list, $lun );
    }
    return ( 0, $luns_list );
}

# This function creates a lun
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success, Fail => error_msg
sub create_lun {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'wrong arrays list' )
      if ( !exists( $hash->{arrays} )
        || !scalar( @{ $hash->{arrays} } ) );

    my $array = shift( @{ $hash->{arrays} } );

    my $name = $hash->{name};

    # if user don't give a name
    # I must find one
    if ( !defined($name) ) {
        my $array_list = get_luns_list($controller);
        my $major      = -1;
        foreach my $array (@$array_list) {
            next if ( $array !~ m/.+\d+$/ );
            my ($tmp_major) = ( $array =~ m/.+(\d+)$/ );
            if ( $tmp_major > $major ) {
                $major = $tmp_major;
            }
        }
        $major++;
        $name = 'l' . $major;
    }

    my $size = $hash->{size};

    # if user don't give a size
    # I set the max size
    if ( !defined($size) ) {
        my ( $ret, $data ) = get_arrays_list($controller);
        return ( $ret, $data ) if ($ret);

        return ( 1, "Unable to find $array array" )
          if ( !grep( /$array/, @{$data} ) );

        my $cmd = 'vgdisplay -c ' . $array;
        ( $ret, $data ) = _exec_cmd($cmd);
        return ( $ret, "Unable to get $array array size : $data" ) if ($ret);

        my @data = split( /:/, $data );
        chomp @data;
        $size = $data[12] * $data[15] . 'k';
    }

    my ($stripe) = scalar( @{ _get_drives_in_array($array) } );

    my $command = "lvcreate -n $name -L $size -i $stripe $array";

    my ( $ret_code, $err, $norm ) = _exec_cmd($command);
    return ( $ret_code, "Array creation failed : $err" ) if ($ret_code);

    return ( 0, 'Lun created successfully' );
}

# This function deletes luns
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub delete_lun {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    return ( 1, "unable to find the controller $controller" )
      if ( $controller !~ m/$CONTROLLER_PREFIX/ );

    return ( 1, 'wrong luns list' )
      if ( !exists( $hash->{luns} )
        || !scalar( @{ $hash->{luns} } ) );

    foreach my $lun ( @{ $hash->{luns} } ) {

        my $cmd = "lvremove -f $lun";
        my ( $ret_code, $data ) = _exec_cmd($cmd);
        return ( $ret_code, "$data" ) if ($ret_code);
    }

    return ( 0, 'Lun deletion completed successfully' );
}

1;
