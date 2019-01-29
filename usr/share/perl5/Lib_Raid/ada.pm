## ######### PROJECT NAME : ##########
##
## ada.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file permits the support of adaptec raid controllers.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Tue Feb  3 12:59:36 2009 Boutonnet Alexandre
## Last update Fri Mar 27 17:10:09 2009 Boutonnet Alexandre
##
## ###################################
##

package ada;
require Lib_Raid::ada_luns;
require Lib_Raid::ada_drives;
require Lib_Raid::ada_controllers;
require Lib_Raid::ada_arrays;
require Lib_Raid::ada_enclosures;
require Lib_Raid::ada_spares;

use strict;
use warnings;
use IPC::Run3;

use Lib_Raid::lib_raid_codes;

use Data::Dumper;

# DEFINE
our $CONTROLLER_PREFIX = 'ada';
our $ada_cmd           = '/usr/sbin/arcconf';

# our $ada_cmd           = '/root/fakearc';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : on)

# GLOBALS
my $CACHE_HASH = {};

# maximum cache duration in seconds
my $CACHELIMIT = 30;

sub AUTOLOAD {
    return ( -1, 'function not implemented' );
}

# This function returns all informations
# about everythings :)
sub get_all_info {
    my $hash = {};

    my ( $ret_code, $data ) = get_controllers_list();
    return ( $ret_code, $data ) if ($ret_code);

    my $tab_controllers = $data;
    foreach my $controller_name (@$tab_controllers) {
        ( $ret_code, $data ) = get_controller_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name} = $data;

        my $local_cache_flag = _enable_cache();

        ( $ret_code, $data ) = get_drives_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{drives} = $data;

        ( $ret_code, $data ) = get_luns_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{luns} = $data;

        ( $ret_code, $data ) = get_arrays_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{arrays} = $data;

        ( $ret_code, $data ) = get_enclosures_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{enclosures} = $data;

        _disable_cache($local_cache_flag);
    }

    return ( 0, $hash );
}

### PRIVATES FUNCTIONS ###

# This function get adapter information
sub _get_adapter_information {
    my ( $controller_number, $hash ) = @_;

    my $cmd = "$ada_cmd getconfig $controller_number AD";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get adapter informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {

        # number of lun/arrays
        ( $hash->{numberofluns} ) =
          ( $line =~ m/.+Logical [d|D]evices\/Failed\/Degraded +\: (\d+)\/.*/ )
          if ( $line =~ m/.+Logical [d|D]evices\/Failed\/Degraded +/ );
        $hash->{numberofarrays} = $hash->{numberofluns};

        # model
        ( $hash->{model} ) = ( $line =~ m/.+Controller Model +\: .+ (.+)/ )
          if ( $line =~ m/.+Controller Model +/ );

        # Vendor
        ( $hash->{vendor} ) = ( $line =~ m/.+Controller Model +\: (.+) .+/ )
          if ( $line =~ m/.+Controller Model +/ );

        # serial number
        ( $hash->{serialnumber} ) =
          ( $line =~ m/.+Controller Serial Number +\: (.+)/ )
          if ( $line =~ m/.+Controller Serial Number +/ );

        # status
        ( $hash->{status} ) = lib_raid_codes::get_state_code(
            ( $line =~ m/.+Controller Status +\: (.+)/ ) )
          if ( $line =~ m/.+Controller Status +/ );
    }

    # BBU special foreach
    my $flag = 0;
    foreach my $line (@tmp_tab) {
        $flag = 1
          if (!$flag
            && $line =~
            m/Controller (Battery|ZMM|Cache Backup Unit) Information/ );

        if ( $flag and $line =~ m/.+Unit Status +\: (.+)/ ) {
            $hash->{BBU}->{status} = lib_raid_codes::get_state_code( ($1) );
        }

        if ( $line =~ m/.+Capacity remaining \s+:\s+(\d+) percent/ and $flag ) {
            $hash->{BBU}->{capacity} = $1;
        }

        if ( $line =~ m/.+Supercap Health\s+:\s+(\d+) percent/ and $flag ) {
            $hash->{BBU}->{capacity} = $1;
        }

        if ( $line =~ m/.+Current Temperature\s+:\s+(\d+) deg C/ and $flag ) {
            $hash->{BBU}->{temperature} = $1;
        }

        if ( $line =~ m/.+Type\s+:\s+(\w+\-\w+)/ and $flag ) {
            $hash->{BBU}->{model} = $1;
        }

        if ( $line =~ m/.+Time remaining/ and $flag ) {
            my (@durations) =
              ( $line =~
m/.+Time remaining \(at current draw\)\s+:\s+(\d+) days, (\d+) hours, (\d+) minutes/
              );

            # conversion en heures
            $hash->{BBU}->{duration} = ( $durations[0] * 24 ) + $durations[1];
        }

    }

    $hash->{WWN} = 'unknown';
    return (0);
}

sub _get_lun_status {
    my ( $controller, $lun ) = @_;

    my $cmd = "$ada_cmd getstatus $controller";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get controller informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    # Logical Device Task:
    #    Logical Device                 : 0
    #    Task ID                        : 100
    #    Current operation              : Build/Verify with fix
    #    Status                         : In Progress
    #    Priority                       : High
    #    Percentage complete            : 92

    my $status_string = '';
    my $progression   = 0;

    my $current_lun = -1;
    foreach my $line (@tmp_tab) {
        $current_lun = $lun
          if ( $line =~ m/Logical [d|D]evice/ && $line =~ m/ : $lun$/ );
        $current_lun = -1
          if ( $line =~ m/Logical [d|D]evice/ && $line !~ m/ : $lun$/ );
        if ( $current_lun > -1 && $current_lun == $lun ) {
            ($status_string) = ( $line =~ m/ : (.+)/ )
              if ( $line =~ m/Current operation/ );
            ($progression) = ( $line =~ m/ : (.+)/ )
              if ( $line =~ m/Percentage complete/ );
        }
    }

    return ( 0, $status_string, $progression );
}

# sub _parse_line_drive_information
# {
#     my ($line, $tmp_hash) = @_;

# }

# This function count hot spare drives
sub _get_number_of_spare {
    my ($controller_number) = @_;

    my $cmd = "$ada_cmd getconfig $controller_number PD";

    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get adapter informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $counter = 0;
    foreach my $line (@tmp_tab) {
        $counter++ if ( $line =~ m/.+State +\: Hot Spare$/ );
    }

    return ( 0, $counter );
}

# translate channel,device into drive number
sub _get_drive_number {
    my ( $controller_number, $channel ) = @_;

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number PD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get physical informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drive_number = -1;
    foreach my $line (@tmp_tab) {
        if ( $line =~ m/ +Device \#(\d+)/ ) {
            $drive_number = $1;
        } elsif ( $line =~ m/Reported Channel,Device/ && $line =~ m/$channel/ )
        {
            return ( 0, $drive_number );
        }
    }
    return ( 1, 'no drive found for this channel,device couple' );
}

# translate connector,device into drive number (5000 series)
# translate enclosure, slot into drive number (6000 series)
sub _get_drive_conn_number {
    my ( $controller_number, $channel ) = @_;

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number PD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get physical informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drive_number = -1;
    foreach my $line (@tmp_tab) {
        if ( $line =~ m/ +Device \#(\d+)/ ) {
            $drive_number = $1;
        } elsif ( $line =~ m/Reported Location/ && $line =~ m/$channel/ ) {
            return ( 0, $drive_number );
        }
    }
    return ( 1, 'no drive found for this channel,device couple' );
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

        # returning data stored in cache
        return ( 0, $CACHE_HASH->{$cmd} );
    }

    run3( $cmd, \undef, \$stdout, \$errout );

    if ($?) {
        chomp($errout);
        return ( 1, $errout, $stdout );
    }

    # setting cache
    $CACHE_HASH->{$cmd} = $stdout;
    $CACHE_HASH->{timestamp}{$cmd} = time() + $CACHELIMIT;

    return ( 0, $stdout );
}

sub _enable_cache {
    my $flag = shift;

    if ( defined($flag) ) {
        $CACHE_FLAG = 1 if ($flag);
        return 0;
    }
    if ( !$CACHE_FLAG ) {
        $CACHE_FLAG = 1;
        return 1;
    }
    return 0;
}

sub _disable_cache {
    my $flag = shift;

    if ( defined($flag) ) {
        $CACHE_FLAG = 0 if ($flag);
        return 0;
    }
    if ($CACHE_FLAG) {
        $CACHE_FLAG = 0;
        return 1;
    }
    return 0;
}

1;
