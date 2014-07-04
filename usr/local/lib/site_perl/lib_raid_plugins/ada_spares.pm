## ######### PROJECT NAME : ##########
##
## ada_spares.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of the ca.pm plugin
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Fri Feb 27 16:49:56 2009 Boutonnet Alexandre
## Last update Thu Mar  5 12:32:45 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

# This function creates an hotspare
# it takes the controller name and an hash with
# informations about the hotspare
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub create_hotspare {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    # I get drives list..
    my $hash_drives = get_drives_info($controller);

    foreach my $drive ( @{ $hash->{drives} } ) {
        my $command = "$ada_cmd setstate $controller_number device ";

        return ( 1, "Drive $drive is not found" )
          if ( !exists( $hash_drives->{$drive} ) );

        return ( 1, "Drive $drive is already an hot spare" )
          if ( $hash_drives->{$drive}->{inarray} ==
            lib_raid_codes::get_drive_inarray_code('hotspare') );

        return ( 1, "Drive $drive is not ready to be used as hot spare" )
          if ( $hash_drives->{$drive}->{inarray} !=
            lib_raid_codes::get_drive_inarray_code('unused') );

        my ( $channel, $id ) =
          ( $hash_drives->{$drive}->{slotnumber} =~ m/(\d+),(\d+)/ );
        $command .= "$channel $id hsp noprompt";

        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        return ( $ret_code, "Hot spare creation failed : $norm" )
          if ($ret_code);
    }
    return ( 0, 'Hot spare creation completed successfully' );

}

# This function deletes an hotspare
# it takes the controller name and an hash with
# informations about the hotspare
# caution: an host spare remains so even
# after being included into an array.
# this command returns the drive to "ready" state.
# it may fails because we can't manage dual drive
# state at this point.
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub delete_hotspare {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    # I get drives list..
    my $hash_drives = get_drives_info($controller);

    foreach my $drive ( @{ $hash->{drives} } ) {
        my $command = "$ada_cmd setstate $controller_number device ";

        # If y get a drive named "h" I rename it "d"
        $drive =~ s/h/d/;

        return ( 1, "Drive $drive is not found" )
          if ( !exists( $hash_drives->{$drive} ) );

        return ( 1, "Drive $drive is not an hot spare" )
          if ( $hash_drives->{$drive}->{inarray} !=
            lib_raid_codes::get_drive_inarray_code('hotspare') );

        my ( $channel, $id ) =
          ( $hash_drives->{$drive}->{slotnumber} =~ m/(\d+),(\d+)/ );
        $command .= "$channel $id RDY noprompt";

        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        return ( $ret_code, "Hot spare deletion failed : $norm" )
          if ($ret_code);
    }

    return ( 0, 'Hot spare deletion completed successfully' );
}

1;
