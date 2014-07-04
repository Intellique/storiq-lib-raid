## ######### PROJECT NAME : ##########
##
## 3wa_luns.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of cw.pm plugin.
##
## ###################################
##
## Made by Boutonnet Alexandre
## Login   <aboutonnet@intellique.com>
##
## Started on  Mon Mar  2 16:18:06 2009 Boutonnet Alexandre
## Last update Thu Mar  5 13:27:47 2009 Boutonnet Alexandre
##
## ###################################
##
use strict;
use warnings;

our $CONTROLLER_PREFIX;

# This function returns an hash containing
# all informations about the lun
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_lun_info {
    my ( $controller, $lun ) = @_;

    my $hash = {};

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get lun informations : $data" )
      if ($ret_code);

    my ($lun_number) = ( $lun =~ m/^l(\d+)/ );
    return ( 1, 'unable to find lun number' ) if ( !defined($lun_number) );

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^u$lun_number/ );
        return ( 2, 'This array/lun is a spare' ) if ( $line =~ m/SPARE/ );
        $hash->{status} = lib_raid_codes::get_state_code(
            $line =~ m/^u\d+ +[\w\-\d]+ +([\w\-]+) +/ );
        ( $hash->{size} ) = ( $line =~ m/.+ +(\w+\.\w+) / );
        $hash->{size} = sprintf( "%.2f", $hash->{size} * 1024 );   # in MB..
    }
    push( @{ $hash->{arrays} }, "a" . $lun_number );

    # Je ne gère pas le nom pour l'instant, j'ai trop la flemme
    $hash->{name} = '';

    return ( 0, $hash );
}

# This function returns the lun list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_luns_list {
    my $controller = shift;

    my $tab = ();

    my ($controller_name) = ( $controller =~ m/$CONTROLLER_PREFIX(\w+)/ );
    return ( 1, "unable to find the controller $controller" )
      if ( !defined($controller_name) );

    # getting informations about drives
    my $cmd = "/$controller_name show all";
    my ( $ret_code, $data ) = _exec_cmd($cmd);
    return ( $ret_code, "unable to get luns informations : $data" )
      if ($ret_code);

    # splitting my output string in an array
    my @tmp_tab = split( /\n/, $data );

    my $luns_list = ();
    foreach my $line (@tmp_tab) {
        next if ( $line !~ m/^u(\d+) / || $line =~ m/SPARE/ );
        my ($lun_number) = ( $line =~ m/^u(\d+) / );
        push( @$luns_list, "l" . $lun_number );
    }
    return ( 0, $luns_list );
}

# This function returns an hash containing
# all luns informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_luns_info {
    my $controller = pop @_;

    my $hash = {};

    my ( $ret_code, $data ) = get_luns_list($controller);
    return ( $ret_code, $data ) if ($ret_code);

    foreach my $lun (@$data) {
        ( $ret_code, $data ) = get_lun_info( $controller, $lun );
        return ( $ret_code, $data ) if ( $ret_code && $ret_code != 2 );

        $hash->{$lun} = $data if ( !$ret_code );
    }
    return ( 0, $hash );
}

1;
