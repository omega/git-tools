package GitHub::Tools::Common;

use HTTP::Request::Common;

use Config::ZOMG;
use feature ':5.10';
use Pithub::Repos;
use Pithub::Orgs::Teams;

use Sub::Exporter -setup => {
    exports => [ qw/config api get post iterate_repos team_repos/ ],
    groups => [ default => [ qw(config api get post iterate_repos team_repos) ] ],
};

my $c = Config::ZOMG->new( name => 'github_tools' )->load;


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

    if (scalar(@ARGV)) {
        my @repos = @ARGV;
        while (scalar(@repos)) {
            $cb->( { name => shift @repos } );
        }
    } else {
        my $p = Pithub::Repos->new(
            auto_pagination => 1,
            prepare_request => \&_mangle_req,
        );

        my $repos = $p->list(org => $org);
        while ( my $repo = $repos->next ) {
            next if $skip->{ $repo->{name} };
            $cb->($repo);
        }
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



1;
