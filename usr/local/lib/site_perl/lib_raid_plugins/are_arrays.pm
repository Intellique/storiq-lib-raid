## ######### PROJECT NAME : ##########
##
## are_arrays.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of are.pm
##
## ###################################
##
## Made by Emmanuel Florac
## Login   <eflorac@intellique.com>
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $are_cmd;

# This function returns arrays informations
# It take the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_arrays_info {
    my ($controller) = @_;


	my $hash = {};
	
#         # Raid Type
#         ( $tmp_hash->{raidtype} ) = ( $line =~ m/ +RAID level +\: (\d+E*)/ )
#           if ( $line =~ m/ +RAID level +/ );
# 
#         # Stripe size
#         ( $tmp_hash->{stripesize} ) =
#           ( $line =~ m/ +Stripe-unit size +\: (\d+)/ )
#           if ( $line =~ m/ +Stripe-unit size +/ );
# 
#         # Size
#         if ( $line =~ m/ +Size +/ ) {
#             ( $tmp_hash->{size} ) = ( $line =~ m/ +Size +\: (\d+)/ );
# 
# # In want in MB now
# # $tmp_hash->{size} = sprintf("%.2f", $tmp_hash->{size} / 1024); # in GB please !
#         }
# 
#         # Array Status
#         if ( $line =~ m/ +Status of logical device +/ ) {
#             $tmp_hash->{status} = lib_raid_codes::get_state_code(
#                 $line =~ m/ +Status of logical device +\: (.*)/ );
#             if ( $tmp_hash->{status} ) {
#                 my ( $err_code, $status_string, $progression ) =
#                   _get_lun_status( $controller_number, $lun_number );
#                 if ( !$err_code && $status_string ) {
#                     $tmp_hash->{status} =
#                       lib_raid_codes::get_state_code($status_string);
#                     $tmp_hash->{progression} = $progression;
#                 }
#             }
#         }
# 

    return ( 0, $hash );
}

# This function returns an hash containing
# all informations about the array
# given in parameter
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_array_info {
#     my ( $controller, $array ) = @_;
# 
#     my ( $ret_code, $data ) = get_arrays_info($controller);
#     return ( $ret_code, $data ) if ($ret_code);
# 
#     return ( 1, 'array not found' ) if ( !exists( $data->{$array} ) );
#     return ( 0, $data->{$array} );
}

# This function returns a list containing
# all arrays name
# This function takes the controller in parameter
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => list, Fail => error_msg
sub get_arrays_list {
    my ($controller) = @_;

    my $cmd = "$are_cmd rsf info";
	
    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

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
# sub get_arrays_from_lun {
#     my ( $controller, $lun ) = @_;
# 
#     my $tab = ();
# 
#     my ( $ret_code, $data ) = get_arrays_info($controller);
#     return ( $ret_code, $data ) if ($ret_code);
# 
#     my ($minor_number) = ( $lun =~ m/l(\d+)/ );
#     return ( 1, 'unable to find lun number' ) if ( !defined($minor_number) );
# 
#     if ( exists( $data->{ "a" . $minor_number } ) ) {
#         push( @$tab, "a" . $minor_number );
#     } else {
#         return ( 1, 'unable to find corresponding arrays' );
#     }
#     return ( 0, $tab );
# }

# This function creates an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => 0, Fail => error_msg
# sub create_array {
#     my ( $obj, $controller, $hash );
# 
#     ( $controller, $hash ) = @_;
#     ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );
# 
#     my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
#     return ( 1, "unable to find the controller $controller" )
#       if ( !defined($controller_number) );
# 
#     return ( 1, 'wrong drives list' )
#       if ( !defined( $hash->{drives} )
#         || !scalar( @{ $hash->{drives} } ) );
# 
#     # For raid level i check if it's a real raid level
#     return ( 1, 'wrong raid level' )
#       if ( !defined( $hash->{raidlevel} )
#         || $hash->{raidlevel} !~ /^-?\d+/ );
# 
#     # I get drives list..
#     my $hash_drives = get_drives_info($controller);
# 
#     my $command = "$are_cmd create $controller_number logicaldrive ";
# 
#     # setting stripesize
#     $command .= "stripesize $hash->{stripesize} "
#       if ( exists( $hash->{stripesize} )
#         && defined( $hash->{stripesize} ) );
# 
#     # setting name
#     $command .= "name $hash->{name} "
#       if ( exists( $hash->{name} ) && defined( $hash->{name} ) );
# 
#     # currently I allways make full sized arrays
#     $command .= 'max ';
# 
#     # raid_level
#     $command .= "$hash->{raidlevel} ";
# 
#     foreach my $drive ( @{ $hash->{drives} } ) {
#         return ( 1, "Drive $drive is not found" )
#           if ( !exists( $hash_drives->{$drive} ) );
#         return ( 1, "Drive $drive is not ready to be used in an new array" )
#           if ( $hash_drives->{$drive}->{inarray} !=
#             lib_raid_codes::get_drive_inarray_code('unused') );
#         my ( $channel, $id ) =
#           ( $hash_drives->{$drive}->{slotnumber} =~ m/(\d+),(\d+)/ );
#         $command .= "$channel $id ";
#     }
# 
#     $command .= 'noprompt';
# 
#     my ( $ret_code, $err, $norm ) = _exec_cmd($command);
#     return ( $ret_code, "Array creation failed : $norm" ) if ($ret_code);
# 
#     return ( 0, 'Array creation completed successfully' );
# }

# This function deletes an array
# It takes the controller name and an hash with
# informations about the array
# This function returns an array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => success_msg, Fail => error_msg
# sub delete_array {
#     my ( $obj, $controller, $hash );
# 
#     ( $controller, $hash ) = @_;
#     ( $obj, $controller, $hash ) = @_ if ( scalar(@_) > 2 );
# 
#     my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
#     return ( 1, "unable to find the controller $controller" )
#       if ( !defined($controller_number) );
# 
#     return ( 1, 'wrong arrays list' ) if ( !exists( $hash->{arrays} ) );
# 
#     my $command = "$are_cmd delete $controller_number logicaldrive ";
# 
#     foreach my $array ( @{ $hash->{arrays} } ) {
#         my ($array_number) = ( $array =~ m/a(\d+)/ );
#         $command .= "$array_number ";
#     }
# 
#     $command .= 'noprompt';
# 
#     my ( $ret_code, $err, $norm ) = _exec_cmd($command);
#     return ( $ret_code, "Array deletion failed : $norm" ) if ($ret_code);
# 
#     return ( 0, 'Array deletion completed successfully' );
# }

1;
