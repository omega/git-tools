package GitHub::Tools::Common;

use strict;
use warnings;

use HTTP::Request::Common;

use Config::ZOMG;
use feature ':5.10';
use Pithub::Repos;
use Pithub::Orgs::Teams;
use Pithub::Repos::Stats;
use Pithub::Users;
use MIME::Base64 qw();

use Data::Dump qw/dd/;

use Sub::Exporter -setup => {
    exports => [ qw/config api get post iterate_repos team_repos repo_stats user/ ],
    groups => [ default => [ qw(config api get post iterate_repos team_repos repo_stats user) ] ],
};

my ($path) = ($INC{'GitHub/Tools/Common.pm'} =~ m|(.*)GitHub/Tools/Common\.pm|);
$path =~ s|lib/$||g; #remove end lib if it is there?

my $c = Config::ZOMG->new( name => 'github_tools', path => $path )->load;

sub config($) {
    return $c->{$_[0]};
}
our $api;
sub api {
    return $api if $api;
    my $g = Net::HTTP::Spore->new_from_specs(
        '../../other/spore-descriptions/services/github/org3.json',
        '../../other/spore-descriptions/services/github/repo3.json',
        {
            #base_url => 'http://github.com/api/v2/',
        },
    );
    $g->enable('Format::JSON');
    $g->enable('Auth::Basic',
        username => config('user') . '',
        password => config 'token'
    );

    $api = $g;
    return $api;
}

our $ua;
sub ua {
    return $ua if $ua;
    my $api = api();

    $ua = $api->api_useragent->clone;
    $ua->cookie_jar( {} );
    return $ua;
}
sub _mangle_req {
    my $req = shift;
    $req->header(
        'Authorization' => 'Basic ' . MIME::Base64::encode(
            config('user') . ':' . config('token'), ''
        )
    );
    return $req;
}
sub get {
    my ($url) = @_;

    my $ua = ua();
    my $req = _mangle_req(GET $url);

    return $ua->request($req);
}

sub post {
    my ($url, $form) = @_;
    my $ua = ua();
    my $req = _mangle_req(POST $url, $form );
    return $ua->request($req);
}


sub iterate_repos {
    my ($org, $cb) = @_;
    my $skip = config 'skip';


    # Short cut if we have only names.
    if (scalar(@ARGV) and not grep /\*/, @ARGV) {
        my @repos = @ARGV;
        while (scalar(@repos)) {
            # Need to fetch this one repo from github, to get propper
            # datastructre
            my $p = Pithub::Repos->new(
                auto_pagination => 1,
                prepare_request => \&_mangle_req,
            );
            my $name = shift @repos;
            $cb->(  $p->get( user => $org, repo => $name )->first );
        }
        return;
    }

    my $pattern = $ARGV[0] || '.';
    $pattern =~ s/\*/.*/g;
    $pattern = qr/$pattern/;

    my $p = Pithub::Repos->new(
        auto_pagination => 1,
        prepare_request => \&_mangle_req,
    );

    my $repos = $p->list(org => $org);
    while ( my $repo = $repos->next ) {
        next if $skip->{ $repo->{name} };
        next unless $repo->{name} =~ $pattern;
        $cb->($repo);
    }
}

sub team_repos {
    my ($team) = @_;
    my $skip = config 'skip';

    my @repos;

    my $p = Pithub::Orgs::Teams->new(
        auto_pagination => 1,
        prepare_request => \&_mangle_req,
    );

    my $res = $p->list_repos( team_id => $team );
    while (my $repo = $res->next) {
        push(@repos, $repo);
    }
    return \@repos;
}

sub repo_stats {
    my ($repo) = @_;

    my $sum_author = sub {
        my $au = shift;
        my $sums = { a => 0, c => 0, d => 0 };
        my @weeks = @{ $au->{weeks} || [] };
        foreach my $w (@weeks) {
            $sums->{$_} += $w->{$_} for qw/a c d/;
        }
        $sums->{weeks} = \@weeks;
        return $sums;
    };

    my $p = Pithub::Repos::Stats->new(
        prepare_request => \&_mangle_req,
        auto_pagination => 1,
    );
    my $res = $p->contributors(
        user => $repo->{owner}->{login},
        repo => $repo->{name},
        wait_for_200 => 3,
    );
    my $sums = {};
    while (my $a = $res->next) {
        next unless $a->{author};
        my $name = $a->{author}->{login} or do {
            dd $a;
        };
        my $sum = $sum_author->($a);
        $sums->{$name} = $sum;
    }
    return $sums;
}

sub user {
    my ($user) = @_;

    my $p = Pithub::Users->new();
    $p->get( user => $user )->next;
}

1;
