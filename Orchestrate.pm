package Orchestrate;
use Mojo::Base 'Mojo::EventEmitter';

use Carp 'croak';
use Mojo::URL;
use Mojo::UserAgent;
use Orchestrate::Collection;
use Data::Dumper;

use constant DEBUG => $ENV{ORCHESTRATE_DEBUG} || 0;

has secret          => undef;
has base_url        => 'https://api.orchestrate.io/v0/';
has secret_url      => undef;
has error           => undef;
has ioloop          => sub { Mojo::IOLoop->new };
has ua              => sub { Mojo::UserAgent->new };
has max_connections => 5;

our $VERSION = '0.01';


sub new {
  shift->SUPER::new->_build(@_);
}

sub collection {
  my ($self, $name) = @_;
  return Orchestrate::Collection->new(orchestrate => $self, name => $name);
}


sub _build {
  my ($self, %args) = @_;
  return $self unless $args{secret};

  $self->secret($args{secret});
  $self->base_url($args{url}) if $args{url};
  $self->_authenticate;
  $self->secret_url(Mojo::URL->new($self->base_url)->userinfo($self->secret));

  return $self;
}

sub _authenticate {
  my $self = shift;

  my $ua = $self->ua;
  my $url = Mojo::URL->new($self->base_url)->userinfo($self->secret);
  my $tx = $ua->head($url);

  croak qq{Authentication failed.} unless $tx->res->is_status_class(200);
}

sub _error {

}

1;