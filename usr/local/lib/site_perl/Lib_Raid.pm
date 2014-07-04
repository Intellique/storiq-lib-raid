## ######### PROJECT NAME : ##########
##
## Lib_Raid.pm for Lib_Raid
##
## ######### PROJECT DESCRIPTION : ###
##
## This library is a part of INTELLIQUE Raid management tools
##
## ###################################
##
## Started on  Tue Feb  3 10:22:33 2009 Boutonnet Alexandre
##
## ###################################
##

package Lib_Raid;

use strict;
use warnings;
use Objet_Conf;

# This var is the path to the plugins directory.
my $raid_plugins_path = '/usr/local/lib/site_perl/lib_raid_plugins/';

# This hash contains the list of all plugins.
my $plugin_list = {
    ada => {
        exe_path    => '/usr/sbin/arcconf',
        loaded      => 0,
        module_name => 'ada.pm',
    },
    are => {
        exe_path    => '/usr/sbin/arc_cli64',
        loaded      => 0,
        module_name => 'are.pm',
    },
    ddn => {
        exe_path    => '/bin/true',
        loaded      => 0,
        module_name => 'ddn.pm',
    },
    lsi => {
        exe_path    => '/usr/sbin/MegaCli',
        loaded      => 0,
        module_name => 'lsi.pm',
    },
    lvm => {
        exe_path    => '/sbin/lvdisplay',
        loaded      => 0,
        module_name => 'lvm.pm',
    },
    mdm => {
        exe_path    => '/sbin/mdadm',
        loaded      => 0,
        module_name => 'mdm.pm',
    },
    twa => {
        exe_path    => '/usr/sbin/tw_cli',
        loaded      => 0,
        module_name => 'twa.pm',
    },
    xyr => {
        exe_path    => '/usr/sbin/LXCR',
        loaded      => 0,
        module_name => 'xyr.pm',
    },
};

# This function calls all available plugins
# and get all informations
# This function returns an hash
sub get_all_info {
    my $verbose = shift;

    my $hash = {};

    _require_all_plugins();

    foreach my $plugin ( sort( keys(%$plugin_list) ) ) {

        # Test if the plugin is instantiated
        next unless $plugin_list->{$plugin}->{'loaded'};

        if ( defined $verbose ) {
            print
"\r                                                                \r";
            print "\rGetting information from $plugin...";
        }

        my ( $err_code, $tmp_hash ) = $plugin->get_all_info();

        if ($err_code) {

            #  	    print $tmp_hash."\n";
            next;
        }

        foreach my $key ( sort keys(%$tmp_hash) ) {
            $hash->{$key} = $tmp_hash->{$key};
        }
    }

    return ($hash);
}

# This function calls all available plugins
# and get each controllers list
# This function returns a list
sub get_all_controllers_list {
    my @list;

    _require_all_plugins();

    foreach my $plugin ( sort( keys(%$plugin_list) ) ) {

        # Test if the plugin is instantiated
        next unless $plugin_list->{$plugin}->{'loaded'};

        my ( $err_code, $tmp_list ) = $plugin->get_controllers_list();
        next if ($err_code);

        push( @list, @{$tmp_list} ) if defined $tmp_list;
    }

    return \@list;
}

# This function calls the plugin method given in parameter
# It takes in parameter :
# - the controller name
# - the plugin function to call
# - a ref to an hash that will be given to the plugin function
# This function returns :
# [0] : 0 => Ok, != O => Fail
# [1] : Ok => 0, Fail => error_msg
sub call_action {
    my ( $controller, $function, $hash ) = @_;

    my ($plugin) = $controller =~ /^(...)/;

    # Test if the plugin is instantiated
    if ( not $plugin_list->{$plugin}->{'loaded'} ) {
        my ( $err, $msg ) = _require_plugin($plugin);
        return ( $err, $msg ) if ($err);
    }

    # Calling function..

    my ( $err, $msg ) = $plugin->$function( $controller, $hash );
    return ( $err, $msg );
}

### PRIVATES FUNCTIONS ###

# This private function requires all plugins
# listed in the plugin_list hash.
# This function returns allways true
sub _require_all_plugins {
    foreach my $plugin ( keys %$plugin_list ) {
        next unless -x $plugin_list->{$plugin}->{'exe_path'};
        next if $plugin_list->{$plugin}->{'loaded'};

        # Trying to instanciate the plugin
        eval {
            require(
                $raid_plugins_path . $plugin_list->{$plugin}->{'module_name'} );
        };

        # Test if it makes an error
        if ($@) {
            print "Warning : unable to require $plugin plugin : $@";
        } else {
            $plugin_list->{$plugin}->{'loaded'} = 1;
        }
    }
    return (0);
}

# This private function requires the plugin
# given in parameter.
# Parameters:
# 1. plugin name (ex : "cx")
sub _require_plugin {
    my $plugin = shift;

    return ( 1, "unknown $plugin plugin" )
      if $plugin_list->{$plugin}->{'loaded'};

    return ( 1,
"client for $plugin is not available. You should install storiq-cli-$plugin."
    ) unless ( -x $plugin_list->{$plugin}->{'exe_path'} );

    # Trying to instanciate the plugin
    eval {
        require(
            $raid_plugins_path . $plugin_list->{$plugin}->{'module_name'} );
    };

    # Test if it makes an error
    if ($@) {
        return ( 1, "unable to require $plugin plugin : $@" );
    } else {
        $plugin_list->{$plugin}->{'loaded'} = 1;
        return 0;
    }
}

# This function loads customisable configuration
# So far only used for DDN controllers
sub load_config {
    my $config_file = '/etc/storiq/libraid.conf';

    my ( $err, $conf ) = new Objet_Conf($config_file);
    warn "Error reading configuration: $conf" if $err;
	
	return (0, $conf);	
}

1;
