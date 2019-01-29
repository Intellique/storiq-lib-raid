## ######### PROJECT NAME : ##########
##
## lsi_arrays.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of cl.pm
##
## ###################################
##
## Made by Emmanuel Florac
## Email   <dev@intellique.com>
##
## Started on  Tue Mar 24 17:44:28 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;
use Data::Dumper;

our $CONTROLLER_PREFIX;
our $lsi_cmd;

# This function returns the arrays list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
# sub get_arrays_list {
#     my $controller = shift;
# 
#     my $tab = ();
# 
#     my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
#     return ( 1, "unable to find the controller $controller" )
#       if ( !defined($controller_name) );
# 
#     # getting informations about drives
#     my $cmd = "$lsi_cmd -LDPDInfo -a$controller_name -NoLog";
#     my ( $ret_code, $data ) = _exec_cmd($cmd);
#     return ( $ret_code, "unable to get arrays informations : $data" )
#       if ($ret_code);
# 
#     # splitting my output string in an array
#     my @tmp_tab = split( /\n/, $data );
# 
#     my $arrays_list = ();
#     foreach my $line (@tmp_tab) {
#         next if ( $line !~ m/^Virtual Drive/ );
#         my ($array_number) = ( $line =~ m/\: (\d+) / );
#         push( @$arrays_list, 'a' . $array_number );
#     }
#     return ( 0, $arrays_list );
# }
# 
# This function returns an hash containing
# all informations about the array
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
# sub get_array_info {
#     my ( $controller, $array ) = @_;
# 
#     my $hash = {};
# 
#     my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
#     return ( 1, "unable to find the controller $controller" )
#       if ( !defined($controller_name) );
# 
#     # getting informations about drives
#     my $cmd = "$lsi_cmd -LDPDInfo -a$controller_name -NoLog";
#     my ( $ret_code, $data ) = _exec_cmd($cmd);
#     return ( $ret_code, "unable to get array informations : $data" )
#       if ($ret_code);
# 
#     my ($array_number) = ( $array =~ m/^a(\d+)/ );
#     return ( 1, 'unable to find array number' )
#       if ( !defined($array_number) );
# 
#     # splitting my output string in an array
#     my @tmp_tab = split( /\n/, $data );
# 
#     my $current_array = -1;
#     my $drive_tab     = ();
#     foreach my $line (@tmp_tab) {
#         if ( $line =~ m/^Virtual Disk/ ) {
#             last if ( $current_array > -1 );
#             my ($tmp_array) = ( $line =~ m/\: (\d+) / );
#             $current_array = $tmp_array if ( $tmp_array == $array_number );
#         }
# 
#         # Status
#         $hash->{status} =
#           lib_raid_codes::get_state_code( $line =~ m/\: ([\w\s]+)/ )
#           if ( $line =~ m/^State:/ );
# 
#         if ( $line =~ m/Reconstruction\s+\: Completed (\d+)/ ) {
#             $hash->{status}      = lib_raid_codes::get_state_code('rebuild');
#             $hash->{progression} = $1;
#         }
#         if ( $line =~ m/Background Initialization\s+\: Completed (\d+)/ ) {
#             $hash->{status}      = lib_raid_codes::get_state_code('initializing');
#             $hash->{progression} = $1;
#         }
# 
#         # Stripe size
#         ( $hash->{stripesize} ) = ( $line =~ m/\: (\d+) KB/ )
#           if ( $line =~ m/Strip Size/ );
# 
#         # Size
#         if ( $line =~ m/^Size/ ) {
# 			
# 			my $unit;
# 			my %factor = ( MB => 1, GB => 1024, TB => 1048576 );
# 			( $hash->{size}, $unit ) = ( $line =~ m/(\d+\.*\d*) (MB|GB|TB)/ ) ;   # Not in MB anymore
# 			
# 			$hash->{size} *=$factor{$unit};
#         }
# 
#         # raidtype
#         ( $hash->{raidtype} ) =
#           lib_raid_codes::get_raid_level_code( $line =~ m/Primary-(\d+),/ )
#           if ( $line =~ m/RAID Level/ );
# 
#         # exit if reached first physical drive
#         last if ( $line =~ m/^PD:/ );
#     }
# 
#     foreach my $line (@tmp_tab) {
# 
#         # Drive
#         if ( $line =~ m/Slot Number/ ) {
#             my ($drive) = ( $line =~ m/\: (\d+)/ );
#             push( @$drive_tab, "d" . $drive );
#         }
#     }
# 
#     $hash->{drives} = $drive_tab;
# 
#     return ( 0, $hash );
# }
# 
# This function returns an hash containing
# all arrays informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_arrays_info {
    my $controller = shift;

    my $hash = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "$lsi_cmd /c$controller_name/vall show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get array informations : $data" )
      if ($ret_code);

	my %factor = ( MB => 1, GB => 1024, TB => 1048576 );

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );
	
    my $current_array = -1;
	my $currentdrive = 0;
		
	foreach my $line (@tmp_tab) {
		$current_array = $1
			if ($line =~ m(/c$controller_name/v(\d+) :) );
		
		$hash->{"a$current_array"}{stripesize} = $1
			if ($line =~ m(Strip Size = (\d+)) );

		$hash->{"a$current_array"}{blocks} = $1
			if ($line =~ m(Number of Blocks = (\d+)) );

		if ( $line =~ m(^\d+\/\d+\s+(\w+)\s+\w+\s+\w+\s+(\w+)\s+(\w+)\s+\-\s+\w+\s+(\d+\.\d+)\s+(\w+)\s+(\w+))) {
			$hash->{"a$current_array"}{raidtype} = lib_raid_codes::get_raid_level_code($1);
			$hash->{"a$current_array"}{status} = $2 eq 'Yes' ? 0 : 2 ;
			$hash->{"a$current_array"}{cachemode} = $3;
			my $unit = $5;
			$hash->{"a$current_array"}{size} = $4 * $factor{$unit};
			$hash->{"a$current_array"}{name} = $6;
			next;			
		}		
		
		if ( $line =~ m(^\d+:(\d+)\s+(\d+)\s+(\w+)\s+($current_array)\s+\d+\.\d*\s+\wB) ) {
			push @{$hash->{"a$current_array"}{drives}}, "d$currentdrive";
			$currentdrive++;
			next;
		}
		
		if ( $line =~ m(Active Operations = ([\w\s]+)\((\d+)%\)) ) {
			$hash->{"a$current_array"}{status} = lib_raid_codes::get_state_code($1); 
			$hash->{"a$current_array"}{progression} = $2;
		}
		
	}
#	die Dumper $hash;
	return ( 0, $hash );
}

1;
