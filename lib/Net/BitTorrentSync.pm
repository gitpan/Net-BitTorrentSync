# ABSTRACT: Perl wrapper for the BitTorrent Sync API

use strict;
use warnings;
package Net::BitTorrentSync;

use LWP::Simple;
use JSON;

my $config;

my $listen;

=head1 NAME

Net::BitTorrentSync - A Perl interface to the BitTorrent Sync API

=head1 VERSION

version 0.1

=head1 SYNOPSIS

	use Net::BitTorrentSync;
	
	set_config('/path/to/config_file');

	add_folder('/path/to/folder');

	my $folders = get_folders();

	remove_folder($folders->[0]->{secret});


=head1 DESCRIPTION

BitTorrent Sync uses the BitTorrent protocol to sync files between two or more machines, or nodes
(computers or mobile phones) without the need of a server. It uses "secrets", a unique hash string
given for each folder that replaces the need for a tracker machine. The more nodes the network has, 
the faster the data will be synched between the nodes, allowing for very fast exchange rates. 
In addition, folders and files can be shared as read-only, or as read and write.

This is a complete wrapper of the published BitTorrent Sync API.
It can be used to connect your Perl application to a running BitTorrent Sync instance, in order
to perform any action such as adding, removing folders/files, querying them, setting preferences,
and fetch information about the BitTorrent Sync instance.

=head1 !WARNING!

The BitTorrent Sync technology and the existing BitTorrent Sync client are not open source or free
software, nor are their specs available in any shape or form other than the API. Therefore, there
is no guarantee whatsoever that the communication between nodes is not being monitored by  
BitTorrent Inc. or by any third party, including the US Government or any Agency on behalf of the 
US Government.

=head1 REQUIREMENTS

In order to run these commands you must have a running instance of the BitTorrent Sync client, 
available for download here: L<http://www.bittorrent.com/sync/downloads>.

No other non-perl requirements are needed.

=head1 METHODS

=head2 set_config

=cut

sub set_config {
	my $path = shift;
	local $/;
	open my $fh, '<', $path or die "Error opening config file $path - $!\n";
	$config = decode_json(<$fh>);
	close $fh;
	$listen = $config->{webui}->{listen};
}

=head2 add_folder

Adds a folder to Sync. If a secret is not specified, it will be generated automatically. 
The folder will have to pre-exist on the disk and Sync will add it into a list of syncing folders.
Returns '0' if no errors, error code and error message otherwise.

    dir (required) - specify path to the sync folder
    secret (optional) - specify folder secret
    selective_sync (optional) - specify sync mode, selective - 1, all files (default) - 0

=cut

sub add_folder {
	my ($dir, $secret, $selective_sync) = @_;
	my $request = "http://$listen/api?method=add_folder&dir=$dir";
	
	$secret and $request .= "&secret=$secret";
	$selective_sync and $request .= '&selective_sync=1';

	return _access_api($request);
}

=head2 get_folders

Returns an array with folders info. 
If a secret is specified, will return info about the folder with this secret.

	[
	    {
			dir		 => "/path/to/dir/"
	        secret	 => "A54HDDMPN4T4BTBT7SPBWXDB7JVYZ2K6D",
	        size	 => 23762511569,
	        type	 => "read_write",
	        files	 => 3206,
	        error	 => 0,
	        indexing => 0
	    }
	]


    secret (optional) - if a secret is specified, will return info about the folder with this secret

=cut 

sub get_folders {
	my ($secret) = @_;
	my $request = "http://$listen/api?method=get_folders";
	
	$secret and $request .= "&secret=$secret";

	return _access_api($request);
}

=head2 remove_folder

Removes folder from Sync while leaving actual folder and files on disk. 
It will remove a folder from the Sync list of folders and does not touch any files or folders on disk.
Returns '0' if no error, '1' if there’s no folder with specified secret.

    secret (required) - specify folder secret

=cut

sub remove_folder {
	my ($secret) = @_;
	my $request = "http://$listen/api?method=remove_folder&secret=$secret";

	return _access_api($request);
}

=head2 get_files

Returns list of files within the specified directory. 
If a directory is not specified, will return list of files and folders within the root folder. 
Note that the Selective Sync function is only available in the API at this time.

	[
	    {
	        name  => "images",
	        state => "created",
	        type  => "folder"
	    },
	    {
	        have_pieces  => 1,
	        name 		 => "index.html",
	        size 		 => 2726,
	        state 		 => "created",
	        total_pieces => 1,
	       	type 		 => "file",
	        download 	 => 1 # only for selective sync folders
	    }
	]


    secret (required) - must specify folder secret
    path (optional) - specify path to a subfolder of the sync folder.

=cut

sub get_files {
	my ($secret, $path) = @_;
	my $request = "http://$listen/api?method=get_files&secret=$secret";
	
	$path and $request .= "&path=$path";

	return _access_api($request);
}

=head2 set_file_prefs

Selects file for download for selective sync folders. 
Returns file information with applied preferences.

    secret (required) - must specify folder secret
    path (required) - specify path to a subfolder of the sync folder.
    download (required) - specify if file should be downloaded (yes - 1, no - 0)

=cut

sub set_file_prefs {
	my ($secret, $path, $download) = @_;
	my $request = "http://$listen/api?method=get_files&secret=$secret&path=$path&download=$download";

	return _access_api($request);
}

=head2 get_folder_peers

Returns list of peers connected to the specified folder.

	[
	    {
	       	id			=> "ARRdk5XANMb7RmQqEDfEZE-k5aI=",
	        connection 	=> "direct", # direct or relay
	        name 		=> "GT-I9500",
	        synced		=> 0, # timestamp when last sync completed
	        download 	=> 0,
	        upload 		=> 22455367417
	    }
	]


    secret (required) - must specify folder secret

=cut

sub get_folder_peers {
	my ($secret) = @_;
	my $request = "http://$listen/api?method=get_folder_peers&secret=$secret";
	return _access_api($request);
}

=head2 get_secrets

Generates read-write, read-only and encryption read-only secrets. 
If ‘secret’ parameter is specified, will return secrets available for sharing under this secret.
The Encryption Secret is new functionality. 
This is a secret for a read-only peer with encrypted content 
(the peer can sync files but can not see their content). 
One example use is if a user wanted to backup files to an untrusted, unsecure, or public location.
This is set to disabled by default for all users but included in the API.
	
	{
	    read_only  => "ECK2S6MDDD7EOKKJZOQNOWDTJBEEUKGME",
	    read_write => "DPFABC4IZX33WBDRXRPPCVYA353WSC3Q6",
	    encryption => "G3PNU7KTYM63VNQZFPP3Q3GAMTPRWDEZ"
	}


    secret (required) - must specify folder secret
    type (optional) - if type=encrypted, generate secret with support of encrypted peer

	NOTE: there seems to be some contradiction in the documentation wrt to secret being required.

=cut

sub get_secrets {
	my ($secret, $type) = @_;

	my $request = "http://$listen/api?method=get_secrets";
	$secret and $request .= "&secret=$secret";
	$type and $request .= "&type=encryption";
	return _access_api($request);
}

=head2 get_folder_prefs

Returns preferences for the specified sync folder.

	{
	    search_lan 		 => 1,
	    use_dht 		 => 0,
	    use_hosts 		 => 0,
	    use_relay_server => 1,
	    use_sync_trash 	 => 1,
	    use_tracker		 => 1
	}

    secret (required) - must specify folder secret

=cut

sub get_folder_prefs {
	my ($secret) = @_;
	my $request = "http://$listen/api?method=get_folder_prefs&secret=$secret";
	return _access_api($request);
}

=head2 set_folder_prefs

Sets preferences for the specified sync folder. 
Parameters are the same as in ‘Get folder preferences’. 
Returns current settings.

    secret (required) - must specify folder secret
    params - { use_dht, use_hosts, search_lan, use_relay_server, use_tracker, use_sync_trash }

=cut

sub set_folder_prefs {
	my ($secret, $prefs) = @_;
	my $request = "http://$listen/api?method=set_folder_prefs&secret=$secret";

	foreach my $pref (keys %{$prefs}) {
		$request .= '&' . $pref . '=' . $prefs->{$pref};
	}
	
	return _access_api($request);
}

=head2 get_folder_hosts

Returns list of predefined hosts for the folder, or error code if a secret is not specified.

	{
	    hosts => [
			"192.168.1.1:4567",
	    	"example.com:8975"
		]
	}

    secret (required) - must specify folder secret

=cut

sub get_folder_hosts {
	my ($secret) = @_;
	my $request = "http://$listen/api?method=get_folder_hosts&secret=$secret";
	return _access_api($request);
}

=head2 set_folder_hosts

Sets one or several predefined hosts for the specified sync folder. 
Existing list of hosts will be replaced. 
Hosts should be added as values of the ‘host’ parameter and separated by commas. 
Returns current hosts if set successfully, error code otherwise.

    secret (required) - must specify folder secret
    hosts (required) - list of hosts, each host should be represented as “[address]:[port]”

=cut

sub set_folder_hosts {
	my ($secret, $hosts) = @_;
	my $request = "http://$listen/api?method=set_folder_hosts&secret=$secret&hosts=";
	
	$request .= join ',', @{$hosts};

	return _access_api($request);
}

=head2 get_prefs

Returns BitTorrent Sync preferences. Contains dictionary with advanced preferences. 
Please see Sync user guide for description of each option.

	{
	    device_name 					=> "iMac",
	    disk_low_priority 				=> "true",
	    download_limit 					=> 0,
	    folder_rescan_interval 			=> "600",
	    lan_encrypt_data 				=> "true",
	    lan_use_tcp 					=> "false",
	    lang 							=> -1,
	    listening_port 					=> 11589,
	    max_file_size_diff_for_patching => "1000",
	    max_file_size_for_versioning 	=> "1000",
	    rate_limit_local_peers 			=> "false",
	    send_buf_size 					=> "5",
	    sync_max_time_diff 				=> "600",
	    sync_trash_ttl 					=> "30",
	    upload_limit 					=> 0,
	    use_upnp 						=> 0,
	    recv_buf_size 					=> "5"
	}

=cut 

sub get_prefs {
	return decode_json (get "http://$listen/api?method=get_prefs");
}

=head2 set_prefs

Sets BitTorrent Sync preferences. Parameters are the same as in ‘Get preferences’. 
Advanced preferences are set as general settings. Returns current settings.

=cut

sub set_prefs {
	my ($secret, $prefs) = @_;
	my $request = "http://$listen/api?method=set_prefs";

	foreach my $pref (keys %{$prefs}) {
		$request .= '&' . $pref . '=' . $prefs->{$pref};
	}
	
	return _access_api($request);
}

=head2 get_os

Returns OS name where BitTorrent Sync is running.

	{ 
		os => "win32" 
	}

=cut

sub get_os {
	return _access_api("http://$listen/api?method=get_os");
}

=head2 get_version

Returns BitTorrent Sync version.

	{ 
		version => "1.2.48" 
	}

=cut

sub get_version {
	return _access_api("http://$listen/api?method=get_version");
}

=head2 get_speed

Returns current upload and download speed.

	{
	    download => 61007,
	    upload => 0
	}

=cut

sub get_speed {
	return _access_api("http://$listen/api?method=get_speed");
}

=head2 shutdown

Gracefully stops Sync.

=cut

sub shutdown {
	return _access_api("http://$listen/api?method=shutdown");
}

sub _access_api {
	my $request = shift;
	my $response = get $request;
	die "API returned undef, check if btsync process is running\n" unless $response;
	return decode_json($response);
}

=head1 TODO

An actual testing suite 

=head1 SEE ALSO

L<http://www.bittorrent.com/sync/developers/api>

=head1 AUTHOR
 
Erez Schatz <erez.schatz@gmail.com>

=head1 LICENSE
 
Copyright (c) 2014 Erez Schatz
 
The BitTorrent Sync API itself, and the description text used in this module is:
 
Copyright (c) 2014 BitTorrent, Inc.

=head1 DISCLAIMER OF WARRANTY
 
BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.
 
IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
