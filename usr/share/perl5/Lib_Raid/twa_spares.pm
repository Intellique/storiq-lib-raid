## ######### PROJECT NAME : ##########
##
## 3wa_spares.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of cw.pm
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Mar  5 12:32:20 2009 Boutonnet Alexandre
## Last update Fri Mar  6 18:13:19 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

# This function creates an hotspare
# it takes the controller name and an hash with
# informations about the hotspare
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub create_hotspare {
    my ( $obj, $controller, $hash );

    our $CONTROLLER_PREFIX;

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    foreach my $drive ( @{ $hash->{drives} } ) {
        my $command = "/$controller_name add type=spare disk=";
        my ($drive_number) = ( $drive =~ m/d(\d+)/ );
        $command .= "$drive_number";

        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        return ( $ret_code, "Array creation failed : $err" ) if ($ret_code);
    }

    return ( 0, 'Hot spare creation completed successfully' );

}

# This function deletes an hotspare
# it takes the controller name and an hash with
# informations about the hotspare
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
sub delete_hotspare {
    my ( $obj, $controller, $hash );

    ( $controller, $hash ) = @_;
    ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    return ( 1, 'wrong drives list' )
      if ( !defined( $hash->{drives} )
        || !scalar( @{ $hash->{drives} } ) );

    foreach my $drive ( @{ $hash->{drives} } ) {
        my ( $ret, $value ) = _get_spare_array( $controller, $drive );
        return ( $ret, $value ) if ($ret);

        my $command = "/$controller_name/u$value del quiet";

        my ( $ret_code, $err, $norm ) = _exec_cmd($command);
        return ( $ret_code, "Hot spare deletion failed : $err" )
          if ($ret_code);
    }

    return ( 0, 'Hot spare deletion completed successfully' );
}

sub _get_spare_array {
    my ( $controller, $drive ) = @_;

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # if drive is given with a h..
    $drive =~ s/h/d/;

    my ($drive_number) = ( $drive =~ m/^d(\d+)/ );
    return ( 1, 'unable to get drive_number' ) if ( !defined($drive_number) );

    # getting informations about the drive
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drive informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @drive_tmp_tab = split( /\n/, $data );

    my ($line) = grep( /^p$drive_number/, @drive_tmp_tab );

    my ($array_number) = ( $line =~ m/^p\d+ +\w+ +u(\d+) / );

    my ($array_line) = grep( /^u$array_number/, @drive_tmp_tab );
    return ( 1, 'This drive is not an hot spare' )
      if ( $array_line !~ m/SPARE/ );

    return ( 0, $array_number );
}

1;
