#!/usr/bin/env perl
use strict;
use MongoDB;
use MongoDB::Connection;
use Geo::Gpx;
use Date::Manip::Date;
use Modern::Perl;

# initialize waypoint array
my @waypoints;

# connect to DB
my $client   = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db       = $client->get_database( 'ukstorm' );
my $tweets  = $db->get_collection( 'tweets' );

# find tweets with geo data attached
my $res = $tweets->find({ geo => { '$type' => 3 } });

# loop through results
while (my $doc = $res->next) {

	# reformat stupid twitter date into unix timestamp
    my $dm = new Date::Manip::Date;
    my $err = $dm->parse($doc->{'created_at'});
    my $unix_time = $dm->printf('%s');

    # create waypoint object
	my $wpt = {
	    lat           => $doc->{'geo'}->{'coordinates'}[0],
	    lon           => $doc->{'geo'}->{'coordinates'}[1],
	    time          => $unix_time,
	    name          => $doc->{'user_screen_name'},
	    cmt           => $doc->{'status_text'},
	    link          => {
	        href => 'https://twitter.com/' . $doc->{'user_screen_name'} . '/' . $doc->{'tweet_id'},
	    }
	};

	# add to array
	push @waypoints, $wpt;
}

# initialize GPX object
my $gpx = Geo::Gpx->new();
# add waypoints
$gpx->waypoints(\@waypoints);
# convert to XML 1.0 format
my $xml = $gpx->xml('1.0');

# open up filehandle
open GPX, ">tweets.xml" or die $!;
# print xml to tweets file
print GPX $xml;
close GPX;