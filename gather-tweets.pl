#!/usr/bin/env perl
use strict;
use Data::Dumper;
use MongoDB;
use MongoDB::OID;
use Net::Twitter;
use Scalar::Util 'blessed';
use Date::Manip::Date;

# twitter API auth data - need to add your own
my $consumer_key    = '';
my $consumer_secret = '';
my $token           = '';
my $token_secret    = '';

# create new Twitter object
my $nt = Net::Twitter->new(
    traits   => [qw/OAuth API::RESTv1_1/],
    consumer_key        => $consumer_key,
    consumer_secret     => $consumer_secret,
    access_token        => $token,
    access_token_secret => $token_secret,
);


my $client   = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $db       = $client->get_database( 'ukstorm' );
my $tweets  = $db->get_collection( 'tweets' );

# find a tweet id from around the time you want to start collecting data
my $since_id = '393726342362980354';

# find a tweet id from around the time you want to finish collecting data
my $max_id = '394487241843556352';

# loop through until we reach the earliest tweet ID
until ($max_id <= $since_id) {
    
    # stop if we go earlier than the since tweet ID
    last if $max_id < $since_id;

    my $statuses;

    # construct search parameters
    my %params = (
                    include_entities => 'true', 
                    q => '#ukstorm',
                    result_type => 'mixed',
                    count => 100,
                    max_id => $max_id,
                  );
    # print to STDOUT to make sure we're looping healthily
    print Dumper(%params);

    # run the search
    eval { $statuses = $nt->search(\%params); };
    
    # respond to STDOUT if there's an error
    if ( my $err = $@ ) {
        print $@ unless blessed $err && $err->isa('Net::Twitter::Error');
    
        print "HTTP Response Code: ", $err->code, "\n",
                "HTTP Message......: ", $err->message, "\n",
                "Twitter error.....: ", $err->error, "\n";
    }

    # loop through statuses and insert into database
    for my $status ( @{$statuses->{'statuses'}} ) {
        my $created_at       = $status->{'created_at'};
        my $user_screen_name = $status->{'user'}{'screen_name'};
        my $status_text      = $status->{'text'};
        my $retweets         = $status->{'retweet_count'};
        my $favorites        = $status->{'favorite_count'};
        my $hashtags         = $status->{'entities'}{'hashtags'};
        my $tweet_id         = $status->{'id'};
        my $geo              = $status->{'geo'};
        my $urls             = $status->{'entities'}{'urls'};

        # intentionally overwrite this each time, so at end of the loop
        # global max_id var is the 'oldest' id within the set (since we're
        # processing new to old)
        $max_id = $tweet_id;
        
        # insert data into mongodb
        $tweets->update({tweet_id => $tweet_id}, { 
                    tweet_id => $tweet_id,
                    created_at => $created_at, 
                    status_text => $status_text,
                    user_screen_name => $user_screen_name,
                    hashtags => $hashtags,
                    retweets => $retweets,
                    favorites => $favorites,
                    geo => $geo,
                    urls => $urls,
                    }, {upsert => 1});

        # print to STDOUT so we know we're getting some useful data!
        print "$status_text\n";
    }
}