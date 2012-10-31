package GitHub::Tools::Common;

use HTTP::Request::Common;

use Config::ZOMG;
use feature ':5.10';

use Sub::Exporter -setup => {
    exports => [ qw/config api get post iterate_repos/ ],
    groups => [ default => [ qw(config api get post iterate_repos) ] ],
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
    api() unless $api; # Need to have api inited;
    my $repos;
    if (scalar(@ARGV)) {
        push( @$repos, { name => shift @ARGV } ) while scalar(@ARGV);
    } else {
        $repos = $api->list_org_repos(org => $org)->body;
    }
    foreach my $r (sort { $a->{name} cmp $b->{name} } @$repos) {
        next if $r->{name} eq 'sandbox';
        $cb->($r);
    }
}



1;
