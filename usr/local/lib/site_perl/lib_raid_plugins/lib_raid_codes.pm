## ######### PROJECT NAME : ##########
##
## codes.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file contains all codes and define for the Lib_Raid
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Feb  5 11:54:16 2009 Boutonnet Alexandre
## Last update Tue Mar 24 17:28:26 2009 Boutonnet Alexandre
##
## ###################################
##

package lib_raid_codes;

use strict;
use warnings;
use Carp;

my $drive_status_codes = {
    'ok'            => 0,
    'sync'          => 0,      # mdadm OK
    'normal'        => 0,      # Areca OK
    'good'          => 0,      # DDN Ok
    'fail'          => 1,
    'rebuilding'    => 2,      # drive used to rebuild an array
    'expanding'     => 3,      # drive used to expand an array
    'drive-removed' => 4,
    'degraded'      => 5,
    'inconsistent'  => 9,      # Adaptec
    'orphan'        => 6,      # drive in an unknown array
    'not-present'   => 7,
    'smart-error'   => 8,
    'smart-failure' => 8,      # 3Ware
    'device-error'  => 9,
    'unknown'       => -128,
    'norm*l'        => 5,      # DDN
    'prtl l'        => 5,
    'prtl r'        => 5,
    'norm*r'        => 0,
    'norm*'         => 0,
	'norm'          => 0,
    'miss'          => 7,
    'miss*l'        => 7,
    'miss*r'        => 7,
    'rbld'          => 2,
    'rbld*r'        => 2,
    'rbld*l'        => 2,
    'amis'          => 5,
    'wtrb'          => 5,
    'wtrb*l'        => 5,
    'wtrb*r'        => 5,
    'mnrb'          => 5,
    'nok'           => 1,
    'unk'           => 1,
    'failed'        => 1,
    'fail'          => 1,
    'critical'      => 1,
    'criticl'       => 1,
    'nored'         => 1,
    'nored (flt)'   => 1,
    'degrad(flt)'   => 1,
    'awl'           => 1,
    'fault'         => 1,
    'flt'           => 1,
    'spare'         => 0,
};

my $drive_codes_to_strings = {
    0 => [ 'Ok',            0 ],
    1 => [ 'FAILED',        2 ],
    2 => [ 'Rebuilding',    1 ],
    3 => [ 'Expanding',     1 ],
    4 => [ 'Drive-removed', 2 ],
    5 => [ 'Degraded',      2 ],
    6 => [ 'Orphan',        1 ],
    7 => [ 'Not Present',   1 ],
    8 => [ 'SMART ERROR',   2 ],
    9 => [ 'DEVICE ERROR',  2 ],
};

my $drive_inarray_codes = {
    'unused'     => -1,
    'hotspare'   => -2,
    'rebuilding' => -3,
    'orphan'     => -4,
    'unknown'    => -128,
};

my $cli_codes = {
    'battery failed or missing'    => 1,     # xyratex bbu
    'build/verify'                 => 4,     # adaptec ...
    'verify with fix'              => 4,     # adaptec
    'clean, degraded, recovering'  => 5,     # md
    'clean, degraded, recovering ' => 5,     # mdadm 3.2 GRRRRR
    'charging'                     => 4,     # 3ware, adaptec, xyratex bbu
    'critical'                     => 6,     # xyratex degraded or broken...
    'degraded'                     => 6,     # adaptec, 3ware
    'partially degraded'           => 6,     # LSI Megaraid
    'degraded-rbld'                => 5,     # 3ware
    'error'                        => 1,     # 3 ware bbu
    'failed'                       => 1,
    'fault'                        => 1,     # 3 ware bbu
    'good'                         => 0,     # xyratex bbu
    'impacted'                     => 2,     # adaptec
    'init-paused'                  => 9,     # 3ware
    'initialized'                  => 0,     # xyratex
    'initializing'                 => 4,     # 3ware, xyratex
    'inoperable'                   => 1,     # 3ware
    'logical device reconfiguring' => 7,     # adaptec
    'migrating'                    => 11,    # 3ware
    'not fault tolerant'           => 0,     # RAID 0 xyratex
    'fault tolerant'               => 0,     # RAID xyratex
    'not installed'                => 3,     # adaptec bbu
    'ok'                           => 0,     # 3ware, LSI, etc
    'clean'                        => 0,     # md
    'clean '                       => 0,     # mdadm 3.2 GRRRRRR
    'normal'                       => 0,     # LSI / DDN enclosure
    'norm'                         => 0,     # DDN
    'optimal'                      => 0,     # adaptec
    'zmm optimal'                  => 0,     # adaptec ZMM
    'ready'                        => 0,     # adaptec AFM-700 / DDN
    'not present'                  => 3,     # adaptec AFM-700
    'rebuild'                      => 5,     # adaptec
    'rebuild-init'                 => 4,     # 3ware
    'rebuild-paused'               => 10,    # 3ware
    'rebuilding'                   => 5,     # 3ware
    'rebuilding array'             => 5,     # xyratex
    'reconfiguration'              => 7,     # adaptec
    'suboptimal, fault tolerant'   => 2,     # adaptec
    'testing'                      => 8,     # 3 ware bbu
    'trusted'                      => 0,     # xyratex
    'unknown'                      => 1,     # 3 ware bbu
    'verifying'                    => 13,    # 3ware
    'weakbat'                      => 1,     # 3 ware bbu
    'true'                         => 0,     # DDN, responsive controller
    'false'                        => 1,     # DDN, failed controller
    'hot_spare'                    => 0,     # DDN, Spare pool
    'spare'                        => 0,     # DDN, Spare pool
    'degrad'                       => 6,     # DDN degraded pool
    "warn"                         => 2,

};

my $bbu_codes_to_strings = {
    0 => 'Ok',
    1 => 'FAILED',
    2 => 'N/A',
    3 => 'Not Present',
    4 => 'Charging',
    5 => 'Testing',
};

# Colors :
# 0 -> normal
# 1 -> yellow
# 2 -> red
my $state_codes_to_strings = {
    0  => [ 'Ok',             0 ],
    1  => [ 'Failed',         2 ],
    2  => [ 'Non Optimal',    2 ],
    3  => [ 'Not Present',    2 ],
    4  => [ 'Build/Verify',   1 ],
    6  => [ 'Degraded',       2 ],
    5  => [ 'Rebuilding',     1 ],
    7  => [ 'Expanding',      1 ],
    8  => [ 'Testing',        1 ],
    9  => [ 'Init Paused',    1 ],
    10 => [ 'Rebuild Paused', 1 ],
    11 => [ 'Migrating',      1 ],
    12 => [ 'Unknown',        2 ],
    13 => [ 'Verifying',      1 ],
};

# 0 -> sata 1
# 1 -> sata 2
# 2 -> sas 3Gb
# 3 -> sata 6Gb
# 4 -> sas 6Gb
my $drive_type = {
    'SATA 1.5 Gb/s' => 0,    # Adaptec
    'SATA 3.0 Gb/s' => 1,    # Adaptec
    'SAS 3.0 Gb/s'  => 2,    # Adaptec
    'SAS 6.0 Gb/s'  => 3,    # Adaptec
    'SATA 1.5 Gbps' => 0,    # 3ware
    'SATA 3.0 Gbps' => 1,    # 3ware
    'SAS 3.0 Gbps'  => 2,    # 3ware
    'SATA 1.5Gb/s'  => 0,    # LSI
    'SATA 3.0Gb/s'  => 1,    # LSI
    'SAS 3.0Gb/s'   => 2,    # LSI
    'SAS 6.0Gb/s'   => 2,    # LSI
    'SAS 12.0Gb/s'  => 2,    # LSI
    'SATA'          => 1,    # Areca, DDN
    'SAS'           => 2,    # Areca, DDN

};

my $raid_string_to_codes = {
    'SINGLE'        => -1,    # 3ware
    '0'             => 0,     # Adaptec, LSI/PERC
    'RAID-0'        => 0,     # 3ware
    '1'             => 1,     # Adaptec, LSI/PERC
    'RAID-1'        => 1,     # 3ware
    '1E'            => 11,    # Adaptec
    '5'             => 5,     # Adaptec, LSI/PERC
    'RAID-5'        => 5,     # 3ware
    '5EE'           => 51,    # Adaptec
    '6'             => 6,     # Adaptec, LSI/PERC
    'RAID-6'        => 6,     # 3ware, Adaptec
    '10'            => 10,    # Adaptec
    'RAID-10'       => 10,    # 3ware, Adaptec
    '50'            => 50,    # Adaptec
    'RAID-50'       => 50,    # 3ware, Adaptec
    '60'            => 60,    # Adaptec
    'RAID-60'       => 60,    # 3ware, Adaptec
    'jbod'          => -2,    # raid_cli
    'single'        => -1,    # raid_cli
    'Simple_volume' => -1,    # Adaptec
    'raid0'         => 0,     # raid_cli
    'raid1'         => 1,     # raid_cli
    'raid5'         => 5,     # raid_cli
    'raid6'         => 6,     # raid_cli
    'raid10'        => 10,    # raid_cli
    'raid50'        => 50,    # raid_cli
    'raid60'        => 60,    # raid_cli
};

my $raid_code_to_string = {
    -2 => 'JBOD',
    -1 => 'SINGLE',
    0  => 'RAID-0',
    1  => 'RAID-1',
    3  => 'RAID-3',
    4  => 'RAID-4',
    5  => 'RAID-5',
    6  => 'RAID-6',
    10 => 'RAID-10',
    11 => 'RAID-1E',
    50 => 'RAID-50',
    51 => 'RAID-5EE',
    60 => 'RAID-60',
};

# This function returns the status code for a drive depending
# of the string status in parameter
# If the status code is unknown, this function returns
# "unknown"
sub get_drive_status_code {
    my $code = shift;
    $code = lc($code);

    return $drive_status_codes->{$code}
      if ( exists( $drive_status_codes->{$code} ) );
    return (-128);    # like unknown
}

# This function returns the inarray state code for a drive depending
# of the string status in parameter
# If the state code is unknown, this function returns
# "unknown"
sub get_drive_inarray_code {
    my $code = shift;

    return $drive_inarray_codes->{$code}
      if ( exists( $drive_inarray_codes->{$code} ) );
    return (-128);    # like unknown
}

# This function returns the numerical value for
# a state sting given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_state_code {
    my $code = shift;
    $code = lc($code);
    return $cli_codes->{$code} if ( exists( $cli_codes->{$code} ) );
    return -1;
}

# This function returns the corresponding bbu state string for
# a state code given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_bbu_state_string {
    my $code = shift;

    return $bbu_codes_to_strings->{$code}
      if ( defined $code and exists( $bbu_codes_to_strings->{$code} ) );
    return "unknown";
}

# This function returns the corresponding state string for
# a state code given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_state_string {
    my $code = shift;

    return $state_codes_to_strings->{$code}[0]
      if ( defined $code and exists( $state_codes_to_strings->{$code}[0] ) );
    return "unknown";
}

# This function returns the corresponding color code for
# a state code given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_state_color_value {
    my $code = shift;

    return $state_codes_to_strings->{$code}[1]
      if ( defined $code and exists( $state_codes_to_strings->{$code} ) );
    return 2;
}

# This function returns the corresponding state string for
# a drive state code given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_drive_state_string {
    my $code = shift;

    return $drive_codes_to_strings->{$code}[0]
      if ( defined $code and exists( $drive_codes_to_strings->{$code}[0] ) );
    return "unknown";
}

# This function returns the corresponding color code for
# a drive state code given in parameter.
# If the string is unknown, the value "unknown" is returned
sub get_drive_state_color_value {
    my $code = shift;

    return $drive_codes_to_strings->{$code}[1]
      if ( exists( $drive_codes_to_strings->{$code}[0] ) );
    return 2;
}

# This function returns the code of the drive type
# depending of the string given in parameter
# If it's not found, returning -1
sub get_drive_type_code {
    my $code = shift;

    return $drive_type->{$code} if ( exists( $drive_type->{$code} ) );
    return -1;
}

# This function returns a numerical code corresponding
# of the raid string given in parameter
# return -128 if unknown
sub get_raid_level_code {
    my $code = shift;

    return $raid_string_to_codes->{$code}
      if ( exists( $raid_string_to_codes->{$code} ) );
    return -128;
}

# This function returns the string corresponding to the
# numerical code given in parameter
sub get_raid_string {
    my $code = shift;

    return $raid_code_to_string->{$code}
      if ( exists( $raid_code_to_string->{$code} ) );
    return "unknown";
}

1;
