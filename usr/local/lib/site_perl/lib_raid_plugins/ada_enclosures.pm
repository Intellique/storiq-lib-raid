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
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Thu Feb 19 17:22:32 2009 Boutonnet Alexandre
## Last update Mon Mar  2 16:21:22 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;
our $ada_cmd;

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

    # getting informations about drives
    my $cmd = "$ada_cmd getconfig $controller_number PD";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get drives informations : $data" )
      if ($ret_code);

    my @tmp_tab = split( /\n/, $data );

    my $tmp_hash         = {};
    my $enclosure_number = -1;
    my $flag_enclosure   = 0;
    my $enclosure_id     = -1;
    foreach my $line (@tmp_tab) {
        if (   $line =~ m/ +Device \#/
            && $line !~ m/ +Device \#$enclosure_number/ )
        {
            if (   $enclosure_number > -1
                && $flag_enclosure
                && $enclosure_id > -1 )
            {
                $hash->{ 'e' . $enclosure_id } = $tmp_hash;
                $tmp_hash = {};
            }
            ($enclosure_number) = ( $line =~ m/ +Device \#(\d+)/ );
            $flag_enclosure = 0;
            $enclosure_id   = -1;
        }
        $flag_enclosure = 1 if ( $line =~ m/ +Device is an Enclosure/ );

        # Slot number

        if ( $line =~ m/ +Reported Channel,Device(\(T:L\))* +\: (\d+,\d+)/ ) {
            $tmp_hash->{slotnumber} = $2;
        }

        # Vendor
        ( $tmp_hash->{vendor} ) = ( $line =~ m/ +Vendor +\: (\w+)/ )
          if ( $line =~ m/ +Vendor +/ );

        # model
        ( $tmp_hash->{model} ) = ( $line =~ m/ +Model +\: (.+)/ )
          if ( $line =~ m/ +Model +/ );

        # Enclosure id
        ($enclosure_id) = ( $line =~ m/ +Enclosure ID +\: (\w+)/ )
          if ( $line =~ m/ +Enclosure ID +/ );
    }
    $hash->{ 'e' . $enclosure_id } = $tmp_hash if ($flag_enclosure);

    return ( 0, $hash );
}

1;
