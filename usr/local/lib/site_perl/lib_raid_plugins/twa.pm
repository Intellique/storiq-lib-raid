## ######### PROJECT NAME : ##########
##
## twa.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file permits the support of 3ware raid controllers.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Mon Feb  9 12:21:06 2009 Boutonnet Alexandre
## Last update Fri Mar 27 17:09:53 2009 Boutonnet Alexandre
##
## ###################################
##

package twa;
require 'lib_raid_plugins/twa_arrays.pm';
require 'lib_raid_plugins/twa_controllers.pm';
require 'lib_raid_plugins/twa_drives.pm';
require 'lib_raid_plugins/twa_luns.pm';
require 'lib_raid_plugins/twa_spares.pm';

use strict;
use warnings;

use IPC::Run3;
use lib_raid_plugins::lib_raid_codes;

# DEFINE
our $CONTROLLER_PREFIX = 'twa';
my $twcli_cmd = '/usr/sbin/tw_cli';

# FLAGS
my $CACHE_FLAG = 1;    # Activating or not the cache (default : off)

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

        ( $ret_code, $data ) = get_drives_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{drives} = $data;

        ( $ret_code, $data ) = get_luns_info($controller_name);
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{luns} = $data;

        ( $ret_code, $data, $hash->{$controller_name}{status} ) =
          get_arrays_info( $controller_name,
            $hash->{$controller_name}{status} );
        return ( $ret_code, $data ) if ($ret_code);
        $hash->{$controller_name}->{arrays} = $data;

        # Je ne peux pas le gerer, je n'ai pas de carte avec enclosure.

        #   ($ret_code, $data) = get_enclosures_info($controller_name);
        #   return ($ret_code, $data) if ($ret_code);
        #   $hash->{$controller_name}->{enclosures} = $data;

        #       _disable_cache($local_cache_flag);
    }

    return ( 0, $hash );
}

####### PIVATES FUNCTIONS ########
sub _get_drive_extra_info {
    my ( $controller_name, $drive_number, $hash ) = @_;

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^p$drive_number / );

        # inarray
        if ( $line =~ m/ +u\d+ / ) {

            #           my $local_cache_flag = _enable_cache();
            my ($array_number) = ( $line =~ m/^p\d+ +[\w-]+ +u(\d+) / );
            if ( defined $array_number ) {
                if ( _is_hotspare_array( $controller_name, $array_number ) ) {
                    $hash->{inarray} =
                      lib_raid_codes::get_drive_inarray_code('hotspare');
                } else {
                    $hash->{inarray} = $array_number;
                }
            }

            #           _disable_cache($local_cache_flag);
        } elsif ( $line =~ m/ +u\? / ) {
            $hash->{inarray} =
              lib_raid_codes::get_drive_inarray_code('orphan');

            # Make drive status orphan..
            $hash->{status} = lib_raid_codes::get_drive_status_code('orphan');
        } else {
            $hash->{inarray} =
              lib_raid_codes::get_drive_inarray_code('unused');
        }

# Enclosure
# Pour l'instant j'ai pas eu d'enclosure, c'est donc completement experimental !
#   if ($line !~ m/^p\d+ +\w+ +.+ +.+ +.+ +.+ \d+ +- +/)
#   {
#       ($hash->{enclosurenumber}) = ($line !~ m/^p\d+ +\w+ +.+ +.+ +.+ +.+ \d+ +(\w+) +/);
#   }
#   else
#   {
        $hash->{enclosurenumber} = -1;

        #   }
    }
}

sub _is_hotspare_array {
    my ( $controller_name, $unit_number ) = @_;

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^u$unit_number / );
        return (1) if ( $line =~ m/SPARE/ );
    }
    return (0);
}

# Commande execution function.
sub _exec_cmd {
    my $cmd = shift;

    my $stdout;
    my $errout;

    $cmd = "$twcli_cmd $cmd";

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

sub _get_raid_string {
    my $code = shift;

    my $raid_code = {
        -2 => 'single',
        -1 => 'single',
        0  => 'raid0',
        1  => 'raid1',
        5  => 'raid5',
        6  => 'raid6',
        10 => 'raid10',
        50 => 'raid50',
        60 => 'raid60',
    };

    return ( $raid_code->{$code} );
}

1;

### VRAC A SUPPRIMER !

#     my ($controller_name) = ($controller =~ m/$CONTROLLER_PREFIX(\w+)/);
#     return (1, "unable to find the controller $controller") if (!defined($controller_name));

#     # getting informations about drives
#     my $cmd = "/$controller_name show all";
#     my ($ret_code, $data) = _exec_cmd($cmd);
#     return ($ret_code, "unable to get drives informations : $data") if ($ret_code);

#     # splitting my output string in an array
#     my @tmp_tab = split(/\n/, $data);

#     foreach my $line (@tmp_tab)
#     {
#   next if ($line !~ m/^p(\d+) /);
#   my ($drive_number) = ($line =~ m/^p(\d+) /);
#   my $drive_name = "d".$drive_number;

#   # Status
#   $hash->{$drive_name}->{status} = lib_raid_codes::get_drive_status_code($line =~ m/^p\d+ +(\w+) /);

#   # inarray
#   if ($line =~ m/ +u\d+ /)
#   {
#       my $local_cache_flag = _enable_cache();
#       my ($array_number) = ($line =~ m/^p\d+ +\w+ +u(\d+) /);
#       if (_is_hotspare_array($controller_name, $array_number))
#       {
#       $hash->{$drive_name}->{inarray} = lib_raid_codes::get_drive_inarray_code('hotspare');
#       }
#       else
#       {
#       $hash->{$drive_name}->{inarray} = $array_number;
#       }
#       _disable_cache($local_cache_flag);
#   }
#   else
#   {
#       $hash->{$drive_name}->{inarray} = lib_raid_codes::get_drive_inarray_code('unused');
#   }

#   # Enclosure
#   # Pour l'instant j'ai pas eu d'enclosure, c'est donc completement experimental !
#   if ($line !~ m/^p\d+ +\w+ +.+ +.+ +.+ +.+ \d+ +- +/)
#   {
#       ($hash->{$drive_name}->{enclosurenumber}) = ($line !~ m/^p\d+ +\w+ +.+ +.+ +.+ +.+ \d+ +(\w+) +/);
#   }
#   else
#   {
#       $hash->{$drive_name}->{enclosurenumber} = -1;
#   }

#   my $local_cache_flag = _enable_cache();

#   # getting informations about the drive
#   $cmd = "/$controller_name/p$drive_number show all";
#   ($ret_code, $data) = _exec_cmd($cmd);
#   return ($ret_code, "unable to get drive informations : $data") if ($ret_code);

#   # splitting my output string in an array
#   my @drive_tmp_tab = split(/\n/, $data);

#   my $drive_type = '';
#   foreach my $d_line (@drive_tmp_tab)
#   {
#       next if ($d_line !~ m/^\/$controller_name\/p$drive_number /);

#       # model & vendor
#       if ($d_line =~ m/ Model /)
#       {
#       ($hash->{$drive_name}->{vendor}) = ($d_line =~ m/Model = (\w+) /);
#       ($hash->{$drive_name}->{model}) = ($d_line =~ m/Model = \w+ (.*)/);
#       }
#       # size
#       ($hash->{$drive_name}->{size}) = ($d_line =~ m/ Capacity = (.+) GB/)
#       if ($d_line =~ m/ Capacity = .+ GB/);
#       if ($d_line =~ m/ Capacity = .+ TB/)
#       {
#       my ($size) = ($d_line =~ m/ Capacity = (.+) TB/);
#       $hash->{$drive_name}->{size} = sprintf("%.2f", $size * 1024); # in GB please !
#       }
#       # serial
#       ($hash->{$drive_name}->{serial}) = ($d_line =~ m/ Serial = (\w+)/)
#       if ($d_line =~ m/ Serial = /);
#       # WWN
#       ($hash->{$drive_name}->{wwn}) = ($d_line =~ m/ WWN = (\w+)/)
#       if ($d_line =~ m/ WWN = /);
#       # drive_type
#       ($drive_type) = ($d_line =~ m/ Drive Type = (\w+)/)
#       if ($d_line =~ m/ Drive Type = /);
#       # drive_type
#       if ($d_line =~ m/ Link Speed = /)
#       {
#       my ($speed) = ($d_line =~ m/ Link Speed = (.+)/);
#       $hash->{$drive_name}->{type} = lib_raid_codes::get_drive_type_code($drive_type.' '.$speed);
#       }
#       # connector number : chai pas encore comment le gerer
#       $hash->{$drive_name}->{connectornumber} = "-1";
#       # slot number : chai pas encore comment le gerer
#       $hash->{$drive_name}->{slotnumber} = "-1";
#   }
#   _disable_cache($local_cache_flag);
#     }
