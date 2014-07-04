## ######### PROJECT NAME : ##########
##
## ddn_controllers.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of ddn.pm
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

use Data::Dumper;

our $CONTROLLER_PREFIX;

# This function returns an hash containing
# all informations about the controller
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_controller_info {
    my $ctl_name;

    if   ( scalar(@_) == 1 ) { $ctl_name = $_[0] }
    else                     { $ctl_name = $_[1] }

    my $cmd = "show subsystem summary";

    # careful: in DDN parlance "subsystem" corresponds to our "controllers"
    # controllers themselves are seen as enclosures

    my ( $ret_code, $ctldata ) = _exec_cmd( $cmd, $ctl_name );
    return ( $ret_code,
        "unable to get subsystem summary from $ctl_name : $ctldata" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $ctldata );
    chomp @tmp_tab;

    my $ctlinfo = {
        vendor         => 'DDN',
        model          => 'unknown',
        numberofspares => 0,
        numberofarrays => 0,
        numberofdrives => -1,
        numberofluns   => -1,
        serialnumber   => -1,
        firmware       => -1,
        status         => 0,
        arrays         => {},
        luns           => {},
        drives         => {},
        'BBU'          => {
            'status'   => 3,
            'duration' => 0,
            'capacity' => 0
        },
    };

    my (
        $ctl_sec, $enc_sec, $array_sec, $disk_sec,
        $bbu_sec, $lun_sec, $spare_sec, $jobs_sec
    );

    foreach my $line (@tmp_tab) {

        if ( $line =~ /\*     Controller\(s\)     \*/ ) {
            $ctl_sec = 1;
            next;
        } elsif ( $line =~ /\*     Physical Disk\(s\)     \*/ ) {
            $ctl_sec  = 0;
            $disk_sec = 1;
            next;
        } elsif ( $line =~ /\*     Pool\(s\)     \*/ ) {
            $disk_sec  = 0;
            $array_sec = 1;
            next;
        } elsif ( $line =~ /\*     Spare Pool\(s\)     \*/ ) {
            $array_sec = 0;
            $spare_sec = 1;
            next;
        } elsif ( $line =~ /\*     Virtual Disk\(s\)     \*/ ) {
            $spare_sec = 0;
            $lun_sec   = 1;
            next;
        } elsif ( $line =~ /\*     Background Jobs     \*/ ) {
            $lun_sec  = 0;
            $jobs_sec = 1;
            next;
        } elsif ( $line =~ /\*     Enclosure\(s\)     \*/ ) {
            $jobs_sec = 0;
            $enc_sec  = 1;
            next;
        } elsif ( $line =~ /\*     UPS\(s\)     \*/ ) {
            $enc_sec = 0;
            $bbu_sec = 1;
        }

        if (    $ctl_sec
            and $line =~
/^\s+(\d+)\s+(\w+)\s+(SECONDARY|PRIMARY)\s+(LOCAL|REMOTE)\s+(\d+[:\d+]+)\s+(\d+)\s+(\w+)(\s+)(\d+)\s+\w+\s+\w+\s+([\w+\+?]+)\s+([\d\.?]+)\s+(\d+)\s+(\w+)/
          )
        {
            $ctlinfo->{firmware}     = $11 . ' (' . $12 . ')';
            $ctlinfo->{name}         = $1;
            $ctlinfo->{role}         = $3;
            $ctlinfo->{serialnumber} = $7;
            next;
        }

        if (    $spare_sec
            and $line =~
            /^\s+(\d+)\s+([\w\-]+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d*\s*$/ )
        {
            $ctlinfo->{numberofspares}++;
            my $sparearray = $1;
            delete $ctlinfo->{arrays}{"a$sparearray"};

            foreach my $drive ( keys %{ $ctlinfo->{drives} } ) {
                $ctlinfo->{drives}{$drive}{inarray} = -2
                  if $ctlinfo->{drives}{$drive}{inarray} == $sparearray;
            }

        }

        if (
            $jobs_sec
            and (
                my (
                    $idx,      $jobtype,  $pool,   $disk, $state,
                    $complete, $priority, $status, $time
                )
                = (
                    $line =~
/^\s+(\d+)\s([\w\s]+)\s+POOL\:(\d+)\s+\(\w+\:?(\d*)\s*\)\s*(\w+)\s+(\d+)%\s+(\d+%)\s{3}(\w*)\s+([\w\:\s]*)/
                )
            )
          )
        {
            if ( $state eq 'RUNNING' ) {

                # rebuilding
                $ctlinfo->{arrays}{"a$pool"}{status} = 5
                  if $jobtype =~ /REBUILD/;
                $ctlinfo->{arrays}{"a$pool"}{status} = 13
                  if $jobtype =~ /VERIFY/;
                $ctlinfo->{arrays}{"a$pool"}{status} = 4
                  if $jobtype =~ /INITIALIZE/;

                $ctlinfo->{arrays}{"a$pool"}{progression} = $complete;

            }
        }

        if (
            $enc_sec
            and (
                my ( $index, $type, $logicid, $model, $state ) = (
                    $line =~
/^\s+(\d+)\s+\w+\s+(CONTROLLER|DISK)\s+(0x\w+)\s+DDN\s+(\w+)\s+\d+\s+[\d\.?\-?]+\s+(\w+)\s*$/
                )
            )
          )
        {

            if ( $type eq 'CONTROLLER' ) {
                $ctlinfo->{model} = $model;

              # there are actually 2 controllers, we must record the worst state
                $ctlinfo->{status} =
                  lib_raid_codes::get_state_code($state) || $ctlinfo->{status};
            }

            $ctlinfo->{enclosures}{"e$index"} = {
                status => lib_raid_codes::get_state_code($state),
                vendor => 'DDN',
                model  => $model,
            };

            next;
        }

        if (    $array_sec
            and $line =~
            /^\s+(\d)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)\s{3}([\s|\w]{9})\s*(\d+)/
          )
        {
            my $arraystate = $3;

            $ctlinfo->{arrays}{"a$1"}{status} =
              lib_raid_codes::get_state_code($arraystate);
            $ctlinfo->{arrays}{"a$1"}{name}       = $2;
            $ctlinfo->{arrays}{"a$1"}{stripesize} = $4;
            $ctlinfo->{arrays}{"a$1"}{raidtype}   = $5;
            $ctlinfo->{arrays}{"a$1"}{size}       = $7 * 1024;

            if ( $arraystate =~ /Spare/i ) {
                $ctlinfo->{numberofspares}++;
            } elsif ( $arraystate =~ /NORMAL/ ) {
                $ctlinfo->{numberofarrays}++;
            } else {
                $ctlinfo->{numberofarrays}++;
                $ctlinfo->{status} = 2;
            }
            next;

        }

        if ( $disk_sec and $line =~ /^Total Physical Disks:\s+(\d+)/ ) {
            $ctlinfo->{numberofdrives} = $1;
            next;
        }

        if (
            $disk_sec
            and my (
                $enc,      $slot,  $vendor,   $model,  $interface,
                $capacity, $rpm,   $firmware, $serial, $arraynum,
                $health,   $index, $state,    $wwn
            )
            = (
                $line =~
/\s+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+([\w|\.]+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\w+)\s+\+?\s(\w+)/
            )
          )
        {

            if ( $arraynum =~ /\d+/ ) {
                push @{ $ctlinfo->{arrays}{"a$arraynum"}{drives} }, "d$index";
            } else {
                $arraynum = -1;
            }
            $ctlinfo->{drives}{"d$index"} = {
                status  => lib_raid_codes::get_drive_status_code($state),
                'model' => $model,
                'enclosurenumber' => $enc,
                'size'            => $capacity * 1024,
                'slotnumber'      => $slot,
                'serialnumber'    => $serial,
                'inarray'         => $arraynum,
                'type' => lib_raid_codes::get_drive_type_code($interface),
                'connectornumber' => '0',
                'vendor'          => $vendor,
                'model'           => $model,
                'firmware'        => $firmware,
            };

            next;
        }

        if ( $line =~ /^Total Virtual Disks:\s+(\d+)/ ) {
            $ctlinfo->{numberofluns} = $1;
            next;
        }

        if (
            $lun_sec
            and (
                my (
                    $idx,       $name,     $state,    $array,
                    $raidlevel, $capacity, $settings, $jobs,
                    $curctl,    $prefctl,  $bgjob
                )
                = (
                    $line =~
/\s+(\d+)\s+(\w+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\w\s]+)\s([\w\s]+?)\s+([\d\(L|R\)]+\s\d)\s+([\d\(L|R\)]+\s\d)\s+(\w+)/
                )
            )
          )
        {
            $ctlinfo->{luns}{"l$idx"} = {
                arrays    => ["a$array"],
                name      => $name,
                size      => $capacity * 1024,
                raidtype  => $raidlevel,
                status    => lib_raid_codes::get_state_code($state),
                masterctl => $curctl,
                prefctl   => $prefctl
            };

        }

        if (
            $bbu_sec
            and (
                my (
                    $idx,      $enc,     $present, $capacity,
                    $duration, $enabled, $acfail,  $health
                )
                = (
                    $line =~
/^\s+(\d)\s+(\d+)\s+\d\s+(TRUE|FALSE)\s+(\d+)%\s+(\d+)\smin\s+(TRUE|FALSE)\s+(TRUE|FALSE)\s+(\w+)/
                )
            )
          )
        {
            # there are 2 BBUs but we conflate both

            $ctlinfo->{BBU}{capacity} = $capacity;
            $ctlinfo->{BBU}{duration} = $duration;
            if   ( $acfail eq 'FALSE' ) { $ctlinfo->{BBU}{acfail} = 0 }
            else                        { $ctlinfo->{BBU}{acfail} = 1 }

            $ctlinfo->{BBU}{status} = 0 if $health eq 'OK';
        }
    }

    return ( 0, $ctlinfo );
}

# This function returns the list of controllers
# This function takes no parameters
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_controllers_list {

    # careful: in DDN parlance "subsystem" corresponds to our "controllers"
    # controllers themselves are seen as enclosures

    # faked: support only one controller, ddn1
    # TBD
    ( my $err, our $config ) = Lib_Raid::load_config();
    return ( 1, "failed to load config : $config" ) if $err;

    my ( undef, @controllers ) = $config->get_section();
    my @return;

    foreach (@controllers) { push @return, lc($_) if m/$CONTROLLER_PREFIX/i }

    return ( 0, \@return );
}

# This function does nothing, there is no rescan ability on DDN controllers
sub rescan_controller {
    return 0;
}

1;
