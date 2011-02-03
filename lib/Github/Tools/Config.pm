package GitHub::Tools::Config;

use Config::ZOMG;

use Sub::Exporter -setup => {
    exports => [ qw/config/ ],
    groups => [ default => [ qw(config) ] ],
};

my $c = Config::ZOMG->new( name => 'github_tools' )->load;


sub config($) {
    return $c->{$_[0]};
}
