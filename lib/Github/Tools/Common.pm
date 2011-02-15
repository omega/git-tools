package GitHub::Tools::Common;

use HTTP::Request::Common;

use Config::ZOMG;

use Sub::Exporter -setup => {
    exports => [ qw/config api get post/ ],
    groups => [ default => [ qw(config api get post) ] ],
};

my $c = Config::ZOMG->new( name => 'github_tools' )->load;


sub config($) {
    return $c->{$_[0]};
}
our $api;
sub api {
    return $api if $api;
    my $g = Net::HTTP::Spore->new_from_spec(
        '../../other/spore-descriptions/services/github/organization.json',
        base_url => 'http://github.com/api/v2/'
    );
    $g->enable('Format::JSON');
    $g->enable('Auth::Basic',
        username => config('user') . '/token',
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
            config('user') . '/token:' . config('token'), ''
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

1;
