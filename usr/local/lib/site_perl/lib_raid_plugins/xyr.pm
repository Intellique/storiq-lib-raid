## ######### PROJECT NAME : ##########
##
## xyr.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a plugin to manage xyratex SAN.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Tue Feb  3 11:27:50 2009 Boutonnet Alexandre
## Last update Mon Feb 16 16:04:32 2009 Boutonnet Alexandre
##
## ###################################
##

# ATTENTION !
# Pour le moment ce plugin ne gÃ¨re qu'un controleur en raison
# des incertitudes concernant le comportement de LXCR avec
# deux baies (ou plus) reliÃ©es a la meme tete nas
# attention, RAIDView/StorView affiche les disques décalés de 1.
package xyr;

use strict;
use warnings;
use IPC::Run3;

use Data::Dumper;

# DEFINE
my $CONTROLLER_PREFIX = 'xyr';
my $lxcr_cmd          = '/usr/sbin/LXCR';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : off)

# GLOBALS
my $CACHE_HASH = {};

# maximum cache duration in seconds
my $CACHELIMIT = 30;

sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

sub get_all_info {
    my $hash = {};

    my ( $ret_code, $data ) = get_controllers_list();
    return ( $ret_code, $data ) if ($ret_code);

    my $controller_name = @$data[0];

    ( $ret_code, $data ) = get_controller_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name} = $data;

    ( $ret_code, $data ) = get_arrays_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{arrays} = $data;

    ( $ret_code, $data ) = get_luns_info( $controller_name, $hash );
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{luns} = $data;

    ( $ret_code, $data ) = get_drives_info($controller_name);
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{drives} = $data;

    ( $ret_code, $data ) =
      get_enclosures_info( $controller_name, $hash->{$controller_name} );
    return ( $ret_code, $data ) if ($ret_code);
    $hash->{$controller_name}->{enclosures} = $data;

    _get_status($hash);

    return ( 0, $hash );
}

# This function returns an hash containing
# all informations about the controller
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controller_info {
    my $controller = shift;

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    _get_allinfo_controller_information( $controller_number, $hash );

    _get_confighdrstruct_controller_information( $controller_number, $hash );

    my ( $err_code, $data ) = _get_drives_count($controller_number);
    return ( $err_code, $data ) if ($err_code);
    $hash->{drives} = $data;
    $hash->{status} = 12;

    return ( 0, $hash );
}

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controllers_list {
    my $cmd =
      $lxcr_cmd . ' -C -g -z cntinfofailstruct -p 0 | grep "Command received"';

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller list : $data" )
      if ($ret_code);

    my ($controller) = ( $data =~ m/.+Controller (\d+).*/ );

    my $return_tab = ();
    push @$return_tab, $CONTROLLER_PREFIX . $controller;
    return ( 0, $return_tab );
}

# This function returns an hash containing
# all arrays informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_arrays_info {
    my $controller = shift;

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # Cette fonction est a completer lorsque je pourrais jouer avec un xyratex..

    my $cmd = "$lxcr_cmd -F -g -z rankconfigstruct -p $controller_number";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @arrayinfo = split( /\n/, $data );

    return 2, undef unless (@arrayinfo);

    if (    $arrayinfo[0] =~ /Error: Raid system does not exist/
        and $controller_number > 0 )
    {
        return ( 1, 'Error: Raid system does not exist' );
    }

    my $currentarray = undef;
    foreach (@arrayinfo) {
        if (
m/^Array:(\d+),\s*RAID\s*(\d+),\s*(\d+)\s*Drives.*(\d+)K Chunk,\s(\d+)\s\wB$/
          )
        {
            $currentarray = "a$1";

            $hash->{$currentarray} = {
                drives     => [],
                raidtype   => $2,
                size       => $5 << 10,
                status     => 12,
                stripesize => $4,
            };

            open my $diskfh, '-|', "$lxcr_cmd -D -g -z alldriveinfostruct";

            # Rank is the ARRAY the disk is part of
            my $rank;
            while (<$diskfh>) {
                if (/^RankNo\s+:\s*(\d+)/) {
                    $rank = "a$1";
                } elsif ( /^SES_SlotId +\: (.*)$/ and $rank eq $currentarray ) {
                    push @{ $hash->{$rank}->{drives} }, "d$1";
                }
            }
            close $diskfh;
        } elsif ( $currentarray
            and ( m/Array\sStatus:\s(.*)/ or m/Fault\sStatus:\s(.*)/ ) )
        {
            if ( lib_raid_codes::get_state_code($1) != -1 ) {
                $hash->{$currentarray}{status} =
                  lib_raid_codes::get_state_code($1);
            }

            if ( $hash->{$currentarray}{status} > 0 ) {

                # getting Array status (rebuild, etc)
                my $cmd =
                  $lxcr_cmd . ' -C -g -z allinfo -p ' . $controller_number;
                my ( $ret_code, $data ) = _exec_cmd($cmd);
                return ( $ret_code,
                    "unable to get controller informations : $data" )
                  if ($ret_code);

                foreach my $line ( split( /\n/, $data ) ) {
                    if ( $line =~
m/^(Rebuilding|Initializing|Expanding|Verifying)\s+status\s*:\s+Yes - Array:(\d+),(?:\s*Drive:\d+ WWN:\w+,)?\s*Complete:(\d+)%$/
                        and $currentarray eq "a$2" )
                    {
                        $hash->{$currentarray}{progression} = $3;
                    }
                }
            }
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

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about drives
    my $cmd =
      $lxcr_cmd . ' -D -g -z alldriveinfostruct -p ' . $controller_number;
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $current_entry = -1;
    my $tmp_hash      = {};
    my $drive_number  = -1;
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/\*+ Entry /
            && $line !~ m/\*+ Entry $current_entry / )
        {
            if ( $current_entry > -1 ) {
                $hash->{ 'd' . $drive_number } = $tmp_hash;
                $tmp_hash                      = {};
                $drive_number                  = -1;

            }
            ($current_entry) = ( $line =~ m/\*+ Entry (\d+) / );
        }

        # Enclosure number
        ( $tmp_hash->{enclosurenumber} ) =
          ( $line =~ m/^EnclosureNo +\: (.*)$/ )
          if ( $line =~ m/^EnclosureNo +/ );

        # Slot number
        ( $tmp_hash->{slotnumber} ) = ( $line =~ m/^SlotNo +\: (.*)$/ )
          if ( $line =~ m/^SlotNo +/ );

        # Drive Number
        ($drive_number) = ( $line =~ m/^SES_SlotId +\: (.*)$/ )
          if ( $line =~ m/^SES_SlotId +/ );

        # Capacity
        if ( $line =~ m/^Capacity +/ ) {
            $line =~ m/^Capacity +\: (\d+) /;

            # Capacity is in decimal GB
            $tmp_hash->{size} = $1 * 1000000000 / 1024 / 1024;
        }

        # Vendor
        ( $tmp_hash->{vendor} ) = ( $line =~ m/^VendorId +\: (\w+) / )
          if ( $line =~ m/^VendorId +/ );

        # model
        ( $tmp_hash->{model} ) = ( $line =~ m/^ProductId +\: (\w+)/ )
          if ( $line =~ m/^ProductId +/ );

        # serial number
        ( $tmp_hash->{serialnumber} ) = ( $line =~ m/^SerialNumber +\: (\w+)/ )
          if ( $line =~ m/^SerialNumber +/ );

        # drive status
        if ( $line =~ m/^DriveStatus +/ ) {
            my ($status) = ( $line =~ m/^DriveStatus +\: (\w+)/ );
            $tmp_hash->{status} = 0;

            $tmp_hash->{status} = 2 if ( $status == 85 );
            $tmp_hash->{status} = 3 if ( $status == 86 );
            $tmp_hash->{status} = 1 if ( $status == 17 );

        }

        # drive state
        if ( $line =~ m/^RankNo +/ ) {
            my ($status) = ( $line =~ m/^RankNo +\: (\d+)/ );
            $tmp_hash->{inarray} = $status;
            $tmp_hash->{inarray} = -3 if ( $status == 243 );
            $tmp_hash->{inarray} = -2 if ( $status == 245 );
            $tmp_hash->{inarray} = -1 if ( $status == 255 );
        }

        #Â WWN
        ( $tmp_hash->{WWN} ) = ( $line =~ m/^abNodeName +\: (\w+)/ )
          if ( $line =~ m/^abNodeName +/ );
    }
    $hash->{ 'd' . $drive_number } = $tmp_hash;

    return ( 0, $hash );
}

sub get_luns_info {
    my ( $controller, $controller_info ) = @_;
    my $hash = {};

    #   my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    #   return ( 1, "unable to find the controller $controller" )
    #       if ( !defined($controller_number) );

    foreach my $array ( keys %{ $controller_info->{$controller}->{arrays} } ) {
        my ($lun_number) = $array =~ /a(\d+)/;

        $hash->{"l$lun_number"} = {
            arrays => [ $array, ],
            status => 0,
            name   => '',
            size => $controller_info->{$controller}->{arrays}->{$array}->{size},
        };
    }

    return ( 0, $hash );
}

sub get_enclosures_info {
    my $controller      = shift;    # useless
    my $controller_data = shift;

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );

    my $cmd = "$lxcr_cmd -E -n -p $controller_number";
    my ( $ret_code, $data ) = _exec_cmd($cmd);

    return ( $ret_code, "unable to get enclosure information : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my ($enclcount) = ( $data =~ m/Enclosures: (\d+)/ );
    my $enclosures;

    for ( 1 .. $enclcount ) {
        $enclosures->{"e$_"}->{model} = $controller_data->{model};
    }

    return ( 0, $enclosures );
}

### PRIVATES FUNCTIONS ###

# This function gets 'allinfo' controller information
sub _get_allinfo_controller_information {
    my ( $controller_number, $hash ) = @_;

    # getting informations about the controller
    my $cmd = $lxcr_cmd . ' -C -g -z allinfo -p ' . $controller_number;
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    # cutting tab to important information only (first part)
    my $counter = 0;
    foreach my $line (@tmp_tab) {

        # counter > 12 is for skipping first controller infos
        last
          if ( $line =~ m/\*+Controller $controller_number.*/
            && $counter > 12 );
        $counter++;
    }
    splice( @tmp_tab, 0, $counter );

    # second part
    $counter = 0;
    foreach my $line (@tmp_tab) {

        # counter > 2 is for skipping the first line
        last if ( $line =~ m/\*+Controller \d+ .*/ && $counter > 2 );
        $counter++;
    }
    splice( @tmp_tab, $counter, -1 );

    # lets go !
    foreach my $line (@tmp_tab) {

        # controller model
        ( $hash->{model} ) = ( $line =~ m/^Controller type is (.*)$/ )
          if ( $line =~ m/^Controller type is / );

        # controller WWN
        ( $hash->{WWN} ) = ( $line =~ m/^Actual WWN +\: (.*)$/ )
          if ( $line =~ m/^Actual WWN +/ );

        # BBU status
        ( $hash->{BBU}->{status} ) = ( $line =~ m/^Battery Status +\: (.*)$/ )
          if ( $line =~ m/^Battery Status +/ );
        ( $hash->{BBU}->{capacity} ) =
          ( $line =~ m/^Battery Capacity +\: (.*)%$/ )
          if ( $line =~ m/^Battery Capacity +/ );
        ( $hash->{BBU}->{duration} ) =
          ( $line =~ m/^Battery Holdup Time +\: (.*) h.*$/ )
          if ( $line =~ m/^Battery Holdup Time +/ );

    }

    if ( $hash->{BBU}->{status} =~ m/not present/ ) {
        $hash->{BBU}->{status} = 3;
    } elsif ( $hash->{BBU}->{status} =~ m/failed/ ) {
        $hash->{status} = 2;
        $hash->{BBU}->{status} = 1;
    } elsif ( $hash->{BBU}->{status} eq 'Good' ) {
        $hash->{BBU}->{status} = 0;
    }

    $hash->{vendor} = 'xyratex';

    return (0);
}

# This function gets 'confighdrstruct' controller information
sub _get_confighdrstruct_controller_information {
    my ( $controller_number, $hash ) = @_;

    my $cmd = $lxcr_cmd . ' -F -g -z confighdrstruct -p ' . $controller_number;
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code,
        "unable to get hardware controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {

        # arrays number
        ( $hash->{numberofarrays} ) = ( $line =~ m/^Total Arrays +\: (.*)$/ )
          if ( $line =~ m/^Total Arrays / );

        # Lun number
        ( $hash->{numberoflun} ) =
          ( $line =~ m/^Total Logical Drives +\: (.*)$/ )
          if ( $line =~ m/^Total Logical Drives / );

        # hot spare number
        ( $hash->{numberofspares} ) = ( $line =~ m/^Total Spares +\: (.*)$/ )
          if ( $line =~ m/^Total Spares / );
    }
    return (0);
}

# This function return the number of drives
sub _get_drives_count {
    my $controller_number = shift;    # currently unused

    my $cmd = $lxcr_cmd . ' -D -n -p ' . $controller_number;
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to count drive : $data" ) if ($ret_code);

    my $return_number = -1;

    ($return_number) = ( $data =~ m/^Number of devices: (\d+)\n/ )
      if ( $data =~ m/^Number of devices/ );

    return ( 0, $return_number );
}

# extract the status from every device status
sub _get_status {
    my $data = shift;

    foreach my $ctl ( keys %$data ) {
        foreach my $class (qw(drives arrays luns enclosures)) {
            foreach my $device ( keys %{ $data->{$ctl}{$class} } ) {
                $$data->{$ctl}{status} = 2
                  if ( exists $data->{$ctl}{$class}{$device}{status}
                    and $data->{$ctl}{$class}{$device}{status} != 0 );
            }
        }
        $data->{$ctl}{status} = 0 if $data->{$ctl}{status} == 12;
    }
}

# Command execution function.
sub _exec_cmd {
    my $cmd = shift;

    my $stdout;
    my $errout;

    if (   $CACHE_FLAG
        && exists( $CACHE_HASH->{$cmd} )
        && $CACHE_HASH->{timestamp}{$cmd} > time() )
    {

        # returning data stocked in cache
        return ( 0, $CACHE_HASH->{$cmd} );
    }

    run3( $cmd, \undef, \$stdout, \$errout );

    if ($?) {
        chomp $errout;
        return ( 1, $errout, $stdout );
    }

    # setting cache
    $CACHE_HASH->{$cmd} = $stdout;
    $CACHE_HASH->{timestamp}{$cmd} = time() + $CACHELIMIT;

    return ( 0, $stdout );
}

1;
