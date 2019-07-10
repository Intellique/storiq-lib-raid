############ PROJECT NAME : ##########
#
#  mdm.pm for Lib_Raid
#
######################################

package mdm;

use strict;
use warnings;

use IPC::Run3;
use Lib_Raid::lib_raid_codes;

our $CONTROLLER_PREFIX = 'mdm';
our $mdm_cmd           = '/sbin/mdadm';

# reste à corriger :
# codes manquants
# lister les disques manquants

sub create_array {
    my ( undef, undef, $data ) = @_;

    my @arrays;
    open( MDSTAT, '<', '/proc/mdstat' )
      or return ( 1, 'Check if md-mod is loaded' );
    while (<MDSTAT>) {
        if (/^md(\d+)/) {
            push @arrays, $1;
        }
    }
    close MDSTAT;

    my $array_index = 0;
    if ( @arrays > 0 ) {
        for my $i ( 0 .. 255 ) {
            my $count = grep { $i != $_ } @arrays;
            if ( $count == @arrays ) {
                $array_index = $i;
                last;
            }
        }
    }

    my $filename = '/dev/md' . $array_index;
    unless ( -b $filename ) {
        unlink $filename if -e $filename;
        qx/mknod $filename b 9 $array_index/;
    }

    my $command = "$mdm_cmd -C $filename";
    $command .= ' -c ' . $data->{stripesize}
      if defined $data->{stripesize};
    $command .= ' -l '
      . $data->{raidlevel} . ' -n '
      . scalar( @{ $data->{drives} } ) . ' '
      . join( ' ', @{ $data->{drives} } );

    qx/ y | $command/;
}

sub delete_array {
    my ( undef, undef, $hash ) = @_;

    return ( 2, '' ) unless defined $hash;

    foreach my $array ( @{ $hash->{arrays} } ) {
        my ($array_number) = $array =~ /^a(\d+)$/;
        my $command = "$mdm_cmd -S /dev/md$array_number";

        print 'mdm: deleting array: ', $array, '...';

        my ($err) = _exec_cmd($command);

        if ($err) {
            print "failed\n";
        } else {
            print "ok\n";
        }
    }
}

sub verify {
    my ( undef, undef, $hash ) = @_;
    my ( $ret_code, $message ) = ( 0, '' );

    return ( 2, '' ) unless defined $hash;
    foreach my $array ( @{ $hash->{arrays} } ) {
        my ($array_number) = $array =~ /^a(\d+)$/;
        my $checkfile      = "/sys/block/md$array_number/md/sync_action";
        my $command        = "echo check > $checkfile";
        if ( -f $checkfile ) {
            my ($err) = _exec_cmd($command);
            if ($err) {
                $message .= "An error occured.\n";
                $ret_code++;
            }
        } else {
            $message .= "Unsupported operation for array $array.\n";
        }
    }

    return ( $ret_code, $message );
}

# This function returns all informations
# about everything :)
sub get_all_info {
    my $hash = {
        mdm => {
            arrays         => {},
            BBU            => { status => 3 },
            drives         => {},
            model          => undef,
            numberofarrays => 0,
            numberofluns   => 0,
            numberofspares => 0,
            serialnumber   => undef,
            status         => -128,
            vendor         => undef,
            WWN            => undef,
        },
    };

    ( $hash->{mdm}{model} )  = qx/uname -r/;
    ( $hash->{mdm}{vendor} ) = qx/uname -s/;
    chomp $hash->{mdm}{model};
    chomp $hash->{mdm}{vendor};

    my @arrays;
    open( MDSTAT, '<', '/proc/mdstat' ) or return ( 1, $hash );
    while (<MDSTAT>) {
        if (/^md(\d+)/) {
            push @arrays, 'a' . $1;
        }
    }
    close MDSTAT;

    foreach my $array_name (@arrays) {
        my ($array_num) = $array_name =~ /^a(\d+)/;
        my $lunname = 'l' . $array_num;

        my $device = '/dev/md' . $array_num;

        my ( $ret_code, $data ) = _exec_cmd("$mdm_cmd --misc -D $device");
        next if $ret_code;

        $hash->{mdm}{numberofarrays}++;

        $hash->{mdm}{arrays}{$array_name} = {
            drives     => [],
            size       => undef,
            status     => 0,
            stripesize => undef,
            raidtype   => undef,
        };

        $hash->{mdm}{luns}{$lunname} = {
            arrays => [$array_name],
            name   => $lunname,
            size   => 0,
            status => 0,
        };
        $hash->{mdm}{numberofluns}++;

        foreach ( split( '\n', $data ) ) {
            if (/Array Size : (\d+)/) {
                $hash->{mdm}{arrays}{$array_name}{size} = $1 / 1024;
                $hash->{mdm}{luns}{$lunname}{size}      = $1 / 1024;
            } elsif (/State : (.*+$)/) {
                $hash->{mdm}{arrays}{$array_name}{status} =
                  lib_raid_codes::get_state_code($1);
                $hash->{mdm}{luns}{$lunname}{status} =
                  lib_raid_codes::get_state_code($1);
                if (   $hash->{mdm}{status} == 0
                    or $hash->{mdm}{status} == -128 )
                {
                    $hash->{mdm}{status} =
                      $hash->{mdm}{arrays}{$array_name}{status};
                }

            } elsif (/Chunk Size : (\d+)/) {
                $hash->{mdm}{arrays}{$array_name}{stripesize} = $1;
            } elsif (/Raid Level : (\w+)/) {
                $hash->{mdm}{arrays}{$array_name}{raidtype} =
                  lib_raid_codes::get_raid_level_code($1);
            } elsif (/Rebuild Status : (\d+)/) {
                $hash->{mdm}{arrays}{$array_name}{progression} = $1;
                $hash->{mdm}{arrays}{$array_name}{status}      = 5;
                $hash->{mdm}{luns}{$lunname}{status}           = 5;
            } elsif (
                /^\s+(\d+)\s+\d+\s+\d+\s+(\d+|-)\s+(\w+)(\s+(\w+)\s+(.+))?/)
            {
                my $disk  = $6;
                my $state = lib_raid_codes::get_drive_status_code($5);

                if ($disk) {
                    $hash->{mdm}{drives}{$disk} = {
                        connectornumber => $2,
                        enclosurenumber => -1,
                        inarray         => $array_name,
                        model           => undef,
                        serialnumber    => 'N/A',
                        size            => undef,
                        status          => $state,
                        type            => -128,
                        vendor          => 'N/A',
                        WWN             => 'N/A'
                    };

                    push @{ $hash->{mdm}{arrays}{$array_name}{drives} }, $disk;

                    my ($shortdisk) = ( $disk =~ m#/dev/([a-z]+)\-?\d*# );

                    if ( -f "/sys/block/$shortdisk/size" ) {
                        open my $sizefh, '<', "/sys/block/$shortdisk/size";
                        $hash->{mdm}{drives}{$disk}{size} = <$sizefh>;
                        close $sizefh;
                        chomp $hash->{mdm}{drives}{$disk}{size};
                        $hash->{mdm}{drives}{$disk}{size} /= 2048;
                    }

                    if ( -f "/sys/block/$shortdisk/device/model" ) {
                        open my $modfh, '<',
                          "/sys/block/$shortdisk/device/model";
                        $hash->{mdm}{drives}{$disk}{model} = <$modfh>;
						$hash->{mdm}{drives}{$disk}{model} =~ s/\s+$//g;
                        chomp $hash->{mdm}{drives}{$disk}{model};
                        close $modfh;
                    }

                    if ( -f "/sys/block/$shortdisk/device/vendor" ) {
                        open my $vfh, '<', "/sys/block/$shortdisk/device/vendor";
                        $hash->{mdm}{drives}{$disk}{vendor} = <$vfh>;
						$hash->{mdm}{drives}{$disk}{vendor} =~ s/\s+$//g;
                        chomp $hash->{mdm}{drives}{$disk}{vendor};
                        close $vfh;
                    }

                    if ( -f "/sys/block/$shortdisk/device/wwid" ) {
                        open my $wfh, '<', "/sys/block/$shortdisk/device/wwid";
						my $wwid = <$wfh>;
                        ( $hash->{mdm}{drives}{$disk}{serialnumber} ) = ( $wwid =~ /(\w+)\s*$/g );
						$hash->{mdm}{drives}{$disk}{vendor} =~ s/\s+$//g;
                        chomp $hash->{mdm}{drives}{$disk}{serialnumber};
                        close $wfh;
                    }

                }
            }
        }
    }

    # OK if no arrays...
    if (    $hash->{mdm}{numberofarrays} == 0
        and $hash->{mdm}{numberofluns} == 0 )
    {
        $hash->{mdm}{status} = 0;
    }

    return ( 0, $hash );
}

sub get_controller_info {
	get_all_info();
}

sub get_controllers_list {
    return ( 0, ['mdm'] );
}

sub _exec_cmd {
    my $cmd = shift;

    my $stdout;
    my $errout;

    run3( $cmd, \undef, \$stdout, \$errout );

    if ($?) {
        chomp $errout;
        return ( 1, $errout, $stdout );
    }

    return ( 0, $stdout );
}

if ( grep { /md_stat/ } qx/lsmod/ ) {
    qx/modprobe md-stat/;
}

1;
