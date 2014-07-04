package Lib_Raid_Rpc;

use RPC::Lite::Client;

my $client = RPC::Lite::Client->new(
    { Transport => 'TCP:Host=127.0.0.1,Port=3307', Serializer => 'JSON', } );

sub get_all_info {
    return $client->Request( 'get_all_info', @_ );
}

sub get_all_controllers_list {
    return $client->Request( 'get_all_controllers_list', @_ );
}


sub call_action {
    return $client->Request( 'call_action', @_ );
}

1;
