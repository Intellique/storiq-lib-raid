## ######### PROJECT NAME : ##########
##
## lsi_drives.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## this file is a part of cl.pm
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

# This function returns the drive list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_drives_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "$lsi_cmd /c$controller_name /dall show";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $drives_list = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/DRIVE/ );
        my ( $enclosure, $drive_number ) =
          ( $line =~ m/ \d+ [\d+|\-]\s+\d+\s+(\d+):(\d+)\s+\d+\s+\w+\s+/ );
        push( @$drives_list, "d" . scalar @$drives_list );
    }
    return ( 0, $drives_list );
}

# # This function returns an hash containing
# # all informations about the drive given in
# # parameter. Controller name had to be given too.
# # [0] : 0 => Ok, != O => Fail
# # [1] : Ok => hash, Fail => error_msg
# sub get_drive_info {
#     my ( $controller, $drive ) = @_;
#     my $hash = {};
#
#     my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
#     return ( 1, "unable to find the controller $controller" )
#       if ( !defined($controller_name) );
#
#     my ($drive_number) = ( $drive =~ m/^d(\d+)/ );
#     return ( 1, 'unable to get drive_number' ) if ( !defined($drive_number) );
#
#     # getting informations about the drive
#     my $cmd = "$lsi_cmd -PDList -a$controller_name -NoLog";
#     my ( $ret_code, $data ) = _exec_cmd($cmd);
#     return ( $ret_code, $data ) if ($ret_code);
#
#     # splitting my output string in an array
#     my @drive_tmp_tab = split( /\n/, $data );
#
#     my $drive_count = -1;
#
#     # caution : enclosure comes before the drive!!
#     my $current_enclosure = 0;
#
#     foreach my $line (@drive_tmp_tab) {
#
#         # Enclosure.. (be carefull by moving this part in the code)
#         $current_enclosure = $1
#           if ( $line =~ m/Enclosure Device ID\: (\d+)/ );
#
#         if ( $line =~ m/^Slot Number/ ) {
#
#             last if ( $drive_count == $drive_number );
#             my ($drive_slot) = ( $line =~ m/\: (\d+)/ );
#             $hash->{enclosurenumber} = $current_enclosure;
# 			$hash->{slotnumber} = $1;
# 			$drive_count ++ ;
#         }
#
#         # drive state
#         if ( $line =~ m/Firmware state: ([\w\(\)]+)/ ) {
#
#             my $state = $1;
#             $hash->{status}  = -128;
#             $hash->{inarray} = -128;
#
#             if ( $state eq 'Online' ) {
#                 $hash->{status} = lib_raid_codes::get_drive_status_code('ok');
#             } elsif ( $state eq 'Offline' ) {
#                 $hash->{status} = lib_raid_codes::get_drive_status_code('fail');
#             } elsif ( $state eq 'Unconfigured(good)' ) {
#                 $hash->{inarray} =
#                   lib_raid_codes::get_drive_inarray_code('unused');
#                 $hash->{status} = lib_raid_codes::get_drive_status_code('ok');
#             } else {
#                 $hash->{inarray} =
#                   lib_raid_codes::get_drive_inarray_code('unused');
#                 $hash->{status} = lib_raid_codes::get_drive_status_code('fail');
#             }
#
#         }
#
#         # Size
#           if ( $line =~ m/^Coerced Size/ ) {
# 		          ( $hash->{size} ) = ( $line =~ m/(\d+\.*\d*) ([M|G])B/ ) ;   # Not anymore in MB
# 				  $hash->{size} *= 1024 if $2 eq 'G'; # convert to MB
#
# 		}
#
#         # Disk model vendor serial (morons, they can't make it proper, Hitachi drives are unparsable
#         if ( $line =~ m/Inquiry Data:\s+(\w+)\s*(Hitachi|Seagate|WD|Fujitsu|Intel)\s+(\w+)\s+([\w\-]+)/ ) {
# 			# morons, don't they test their f*cking app?
#
#             $hash->{model}        = $3;
#             $hash->{vendor}       = $2;
#             $hash->{serialnumber} = $1;
# 			$hash->{firmware} = $4;
#
# 		}
#
#         # Connector
#         if ( $line =~ m/Connected Port Number: (\d+)/ ) {
#             $hash->{connectornumber} = $1;
#         }
#
#         # connection type and speed
#         if ( $line =~ m/PD Type: (\w+)/ ) {
#             $hash->{type} = $1;
#         }
#         if ( $line =~ m/Link Speed: ([\w\.\/]+)/ ) {
#             $hash->{type} =
#               lib_raid_codes::get_drive_type_code( $hash->{type} . ' ' . $1 );
#         }
#
#     }
#
#     ( $ret_code, $data ) =
#       _get_array_from_drive( $controller_name, $drive_number );
#
#     return ( $ret_code, $data ) if ($ret_code);
#     $hash->{inarray} = $data;
#
#     return ( 0, $hash );
# }

# This function returns an hash containing
# all drives informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_drives_info {
    my $controller = shift;
    my $hash       = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # we need enclosures first
    my @enclosures;
    my $cmd = "$lsi_cmd /c$controller_name/eall show";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, $data ) if ($ret_code);

    my @enc_tmp_tab = split( /\n/, $data );

    foreach my $line (@enc_tmp_tab) {
        if ( $line =~ /^\s+(\d+)\s+\w+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ) {
            push @enclosures, $1 if $1 != 252;
        }
    }

    # look for all drives in each enclosure
    foreach my $enc (@enclosures) {
        $cmd = "$lsi_cmd /c$controller_name/e$enc/sall show all";
        ( $ret_code, $data ) = _exec_cmd($cmd);
        return ( $ret_code, $data ) if ($ret_code);
        my @dr_tmp_tab = split( /\n/, $data );
        my $currentdrive = -1;

        foreach my $line (@dr_tmp_tab) {
            if ( $line =~ m(^Drive /c$controller_name/e$enc/s(\d+) :) ) {
                $currentdrive++;
                $hash->{"d$currentdrive"}{enclosurenumber} = $enc;
                $hash->{"d$currentdrive"}{slotnumber}      = $1;
                $hash->{"d$currentdrive"}{status}          = -128;
                next;
            }
            $hash->{"d$currentdrive"}{serialnumber} = $1
              if ( $line =~ m(SN = (\w+)) );

            $hash->{"d$currentdrive"}{vendor} = $1
              if ( $line =~ m(Manufacturer Id = (\w+)) );

            $hash->{"d$currentdrive"}{model} = $1
              if ( $line =~ m(Model Number = (\w+)) );

            $hash->{"d$currentdrive"}{connectornumber} = $1
              if ( $line =~ m(Connected Port Number = (\d+)) );

            $hash->{"d$currentdrive"}{WWN} = $1
              if ( $line =~ m(WWN = (\w+)) );

            # interface and speed aren't on the same line
            if ( $line =~
m(^$enc:\d+\s+\d+\s+(\w+)\s+([\d+|\-])\s+\d+\.\d+\s+\w+\s+(\w+)\s+(\w+))
              )
            {
                $hash->{"d$currentdrive"}{status}  = $1;
                $hash->{"d$currentdrive"}{inarray} = $2;
                if ( $hash->{"d$currentdrive"}{status} =~ /DHS|GHS/ ) {
                    $hash->{"d$currentdrive"}{inarray} = -2;    #hot spare
                }

                # not in an array
                $hash->{"d$currentdrive"}{inarray} = -1
                  if $hash->{"d$currentdrive"}{inarray} eq '-';
                $hash->{"d$currentdrive"}{status} =
                  lib_raid_codes::get_drive_status_code(
                    $hash->{"d$currentdrive"}{status} );
                $hash->{"d$currentdrive"}{type}   = $3;
                $hash->{"d$currentdrive"}{medium} = $4;
            }
            if ( $line =~ m(Link Speed = (\d+\.\d+Gb\/s)) ) {
                $hash->{"d$currentdrive"}{type} =
                  lib_raid_codes::get_drive_type_code(
                    $hash->{"d$currentdrive"}{type} . ' ' . $1 );
            }

            # size must be calculated
            if ( $line =~ m(Logical Sector Size = (\d+)\s*(\w+)) ) {

                $hash->{"d$currentdrive"}{blocksize} = $1 eq '512' ? 512 : 4096;

                $hash->{"d$currentdrive"}{size} *=
                  $hash->{"d$currentdrive"}{blocksize} / 2**20

            }
            if ( $line =~ m(Raw size = \d+\.\d+ \wB \[(\w+) Sectors\]) ) {
                no warnings 'portable';
                $hash->{"d$currentdrive"}{size} = hex($1);
                use warnings 'portable';
            }
        }
    }

    return ( 0, $hash );
}

sub _get_array_from_drive {
    my ( $controller_name, $drive_number ) = @_;

    # getting informations about drives
    my $cmd = "$lsi_cmd -LDPDInfo -a$controller_name -NoLog";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get array informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @array_tmp_tab = split( /\n/, $data );

    my $current_array = -1;
    my $found;

    foreach my $line (@array_tmp_tab) {
        if ( $line =~ m/Slot Number: $drive_number/ ) {
            $found = 1;
            last;
        }

        ($current_array) = ( $line =~ m/\: (\d+) / )
          if ( $line =~ m/^Virtual Disk/ );
    }

    $current_array = -1 if not $found;

    return ( 0, $current_array );
}

1;
