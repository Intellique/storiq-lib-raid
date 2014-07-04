## ######### PROJECT NAME : ##########
##
## lsi_luns.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This file is a part of lsi.pm plugin.
##
## ###################################
##
## Made by Florac Emmanuel
## Login   <eflorac@intellique.com>
##
## Started on  mer. avril 27 11:46:56 CEST 2011 Florac Emmanuel
##
##
## ###################################
##
use strict;
use warnings;

# This function returns an hash containing
# all informations about the lun
# given in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_lun_info {
    my ( $controller, $array ) = @_;

    # TODO
    return get_array_info( $controller, $array );
}

# This function returns the lun list
# It takes the controller name in parameter
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => array, Fail => error_msg
sub get_luns_list {
    my $controller = shift;

    # TODO
    return get_array_list($controller);
}

# This function returns an hash containing
# all luns informations
# It takes the controller name in parameter
# This function returns a array with :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => hash, Fail => error_msg
sub get_luns_info {
    my $controller = shift;

    my ( $null, $arrays_info ) = get_arrays_info($controller);
    my $luns_info;

    foreach my $array ( keys %$arrays_info ) {
        my $lun = $array;
        $lun =~ s/a/l/g;

        $luns_info->{$lun} = {
            'arrays' => [$array],
            'status' => $arrays_info->{$array}{status},
            'size'   => $arrays_info->{$array}{size},
            'name'   => '',
        };
    }

    return ( 0, $luns_info );
}

1;
