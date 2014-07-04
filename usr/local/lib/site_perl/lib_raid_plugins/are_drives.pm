## ######### PROJECT NAME : ##########
##
## are_drives.pm for Lib_Raid
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
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $are_cmd;

# This function returns the drive list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drives_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_num) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_num) );

    # getting informations about drives
    my @cmdparams = ( "set curctrl=$controller_num\n", "disk info\n", "exit\n");
	my ( $ret_code, $data ) = _exec_cmd($are_cmd, @cmdparams);
	
	return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code eq 1);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drives_list = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^\s+(\d+)\s+(\d+)\s+SLOT\s+(\d+)\s+(\w+)\s+(\w+)\s+([\d\.]+[G|M|T]B)\s+([\w\s]+)/ );
        my $drive_number = $1;
        push( @$drives_list, "d" . $drive_number );
    }
    return ( 0, $drives_list );
}

# This function returns an hash containing
# all informations about the drive given in
# parameter. Controller name had to be given too.
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drive_info {
    my ( $controller, $drive ) = @_;
	print "#********** get_drive_info $controller  $drive ********\n";
    my $hash = {};

    my ($controller_num) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_num) );

    my ($drive_number) = ( $drive =~ m/^d(\d+)/ );
    return ( 1, 'unable to get drive_number' ) if ( !defined($drive_number) );
	
	# Drive Array (run first because of cache execution time out)
	$hash->{inarray} = _get_array_from_drive($controller_num, $drive_number);
	
	# Drive details
    my $cmd = "$are_cmd";
    my @cmdparams = ( "set curctrl=$controller_num\n", "disk info drv=$drive_number\n", "exit\n");
	 
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

	foreach my $line ( @tmp_tab ) {
		# interface and WWN
		if ($line =~ /^Device Type\s+:\s+(SATA|SAS)\((\w+)\)/ ) {
			$hash->{type} = lib_raid_codes::get_drive_type_code($1);
			$hash->{WWN} = $2;
		} 
		
		# Enclosure, Slot
		if ($line =~ /^Device Location\s+:\s+Enclosure#(\d+)\s+SLOT\s+(\d+)/ ) {
			$hash->{enclosurenumber} = $1;
			$hash->{slotnumber} = $2;
			$hash->{connectornumber} = -1 ; # not available
		} 
		
		# vendor, model
		if ($line =~ /^Model Name\s+:\s+(\w+)\s+(\w+)/ ) {
			$hash->{vendor} = $1;
			$hash->{model} = $2;
		}
		
		# Serial #
		if ($line =~ /^Serial Number\s+:\s(\w+)/ ) {
			$hash->{serialnumber} = $1;
		}
			
		# Firmware
		if ($line =~ /^Firmware Rev\.\s+:\s([\w\.]+)/ ) {
			$hash->{firmware} = $1;
		}
		
		# Size
		if ($line =~ /^Disk Capacity\s+:\s(\d+\.?[\d+]?)([G|T|M])B/ ) {
			$hash->{size} = $1;
			$2 eq 'G' ? $hash->{size} *= 1000 : 
				$2 eq 'T' ? $hash->{size} *= 1000000 : undef ;
		}
		
		# State
		if ($line =~ /^Device State\s+:\s(\w+)/ ) {
			$hash->{status} = lib_raid_codes::get_drive_status_code($1);
		}
		
		# Temperature
		if ($line =~ /^Device Temperature\s+:\s(\d+\.?[\d+]?) C/ ) {
			$hash->{temperature} = $1;
		}
		
	}
    return ( 0, $hash );
}

# This function returns an hash containing
# all drives informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drives_info {
    my $controller = shift;
	
	# print "#********** get_drives_info $controller ********\n";
	
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

sub _get_array_from_drive {
    my ( $controller_name, $drive_number ) = @_;

    # getting informations about drives
    my $cmd = "$are_cmd disk info";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get all drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @array_tmp_tab = split( /\n/, $data );

    my $current_array = -1;
    my $found;

    foreach my $line (@array_tmp_tab) {
        next if ( $line !~ m/^\s+(\d+)\s+(\d+)\s+SLOT\s+(\d+)\s+(\w+)\s+(\w+)\s+([\d\.]+[G|M|T]B)\s+([\w\s]+)/ );
		
		
    }

    $current_array = -1 if not $found;

    return ( 0, $current_array );
}

1;
