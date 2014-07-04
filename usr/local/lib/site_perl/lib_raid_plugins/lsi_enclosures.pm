## ######### PROJECT NAME : ##########
##
## ada_enclosures.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of the ca.pm package.
##
## ###################################
##
## Made by Florac Emmanuel
## Login   <eflorac@intellique.com>
##
## Started on  mercredi 27 avril 2011, 15:36:20 (UTC+0200) Florac Emmanuel
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $lsi_cmd;

# This function returns an hash containing
# all informations about the enclosure
# given in parameter
# This function returns an enclosure with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_enclosure_info {
    my ( $controller, $enclosure ) = @_;

    my ( $ret_code, $data ) = get_enclosures_info($controller);
    return ( $ret_code, $data ) if ($ret_code);

    return ( 1, 'enclosure not found' ) if ( !exists( $data->{$enclosure} ) );
    return ( 0, $data->{$enclosure} );
}

# This function returns an hash containing all
# info about enclosures
# This function takes the controller name in
# parameter
# This function returns an array  with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_enclosures_info {
    my $controller = shift;

    my $hash = {};

    my ($controller_number) = ( $controller =~ m/$CONTROLLER_PREFIX(\d+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_number) );

    # getting informations about enclosures
    my $cmd = "$lsi_cmd -EncInfo -a$controller_number";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get enclosures information : $data" )
      if ($ret_code);

    my @tmp_tab = split( /\n/, $data );

    my $tmp_hash         = {};
    my $enclosure_number = -1;
    my $enclosure_id     = -1;

    foreach my $line (@tmp_tab) {
        if ( $line =~ m/^\s+Enclosure (\d+):/ ) {
            $hash->{ 'e' . $enclosure_id } = $tmp_hash
              if $enclosure_number >= 0;
            $enclosure_number = $1;

            # reset
            $tmp_hash = {
                vendor         => 'Unknown',
                model          => 'Unknown',
                status         => -128,
                numberofslots  => -1,
                numberofdrives => -1,
                numberofpws    => -1,
                connector      => '-1',

            };

        } else {
            $enclosure_id = $1 if $line =~ /^\s+Device ID\s+:\s+(\d+)/;
            $tmp_hash->{vendor} = $1
              if $line =~ /^\s+Vendor Identification\s+:\s+([\w\s]+)/;
            $tmp_hash->{model} = $1
              if $line =~ /^\s+Product Identification\s+:\s+(\w+)/;
            $tmp_hash->{numberofslots} = $1
              if $line =~ /^\s+Number of Slots\s+:\s+(\d+)/;
            $tmp_hash->{numberofdrives} = $1
              if $line =~ /^\s+^\s+Number of Physical Drives\s+:\s+(\d+)/;
            $tmp_hash->{numberofpws} = $1
              if $line =~ /^\s+Number of Power Supplies\s+:\s+(\d+)/;
            $tmp_hash->{status} = lib_raid_codes::get_state_code($1)
              if $line =~ /^\s+Status\s+:\s+(\w+)/;

            # connector
        }
    }

    # Apparently there's always an enclosure 252 for SGPIO, see
    # http://en.wikipedia.org/wiki/SGPIO
    # This enclosure should be ignored
    if ( $tmp_hash->{model} ne 'SGPIO' and $enclosure_number >= 0 ) {
        $hash->{ 'e' . $enclosure_id } = $tmp_hash;
    }

    return ( 0, $hash );
}

1;
