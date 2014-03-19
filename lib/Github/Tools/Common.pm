package Github::Tools::Common;

use strict;
use warnings;

use HTTP::Request::Common;
use Carp;
use Config::ZOMG;
use feature ':5.10';
use Pithub::Repos;
use Pithub::Orgs::Teams;
use Pithub::Repos::Stats;
use Pithub::Users;
use Pithub::Repos::Commits;
use Pithub::Repos::Statuses;
use MIME::Base64 qw();

use Data::Dump qw/dd/;

use Sub::Exporter -setup => {
    exports => [ qw/
        list_org_teams add_team_repo
        list_repo_hooks update_repo_hook add_repo_hook
        config api get post iterate_repos team_repos repo_stats user
        commit_comments set_status list_statuses/ ],
    groups => [
        default => [ qw(
            list_org_teams add_team_repo
            list_repo_hooks update_repo_hook add_repo_hook
            config api get post iterate_repos team_repos repo_stats user
            commit_comments set_status list_statuses
        )]
    ],
};

my ($path) = ($INC{'Github/Tools/Common.pm'} =~ m|(.*)Github/Tools/Common\.pm|);
$path =~ s|lib/$||g; #remove end lib if it is there?

$path ||= '.';
my $c = Config::ZOMG->new( name => 'github_tools', path => $path )->load;

sub config($) {
    return $c->{$_[0]};
}
sub api {
    Carp::confess "API deprecated";
}

sub ua {
    Carp::croak "ua deprecated";
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
    Carp::croak "get deprecated";
}
sub post {
    Carp::croak "post deprecated";
}

sub list_repo_hooks {
    my %opts = @_;
    my $hooks = Pithub::Repos::Hooks->new(
        prepare_request => \&_mangle_req,
    )->list(%opts);
    my @hooks;
    while ( my $hook = $hooks->next ) {
        push @hooks, $hook;
    }
    return wantarray ? @hooks : \@hooks;
}
sub update_repo_hook {
    my %opts = @_;
    Pithub::Repos::Hooks->new(
        prepare_request => \&_mangle_req,
    )->update(%opts);
}

sub add_repo_hook {
    my %opts = @_;
    Pithub::Repos::Hooks->new(
        prepare_request => \&_mangle_req,
    )->create(%opts);
}


sub list_org_teams {
    my $org = shift || config 'org';

    my $teams = Pithub::Orgs::Teams->new(
        prepare_request => \&_mangle_req,
    )->list( org => $org );

    my @teams;
    while ( my $team = $teams->next ) {
        push @teams, $team;
    }
    return wantarray ? @teams : \@teams;
}

sub add_team_repo {
    my %opts = @_;
    Pithub::Orgs::Teams->new(
        prepare_request => \&_mangle_req,
    )->add_repo(
        team_id => $opts{team},
        repo    => $opts{repo},
    );
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
