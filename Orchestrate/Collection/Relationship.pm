package Orchestrate::Collection::Relationship;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate name key kinds)];

sub get_related {
  my $self = shift;
  my $url = $self->orchestrate->secret_url->clone;
  my $ua  = $self->orchestrate->ua;

  $url->path($self->name.'/'.$self->key.'/relations/');

  if ( ref $self->kinds ) {
    push @{$url->path}, $_ for @{$url->path};
  }
  else {
    $url->path($self->kinds);
  }

  $url->path->trailing_slash(0);
  say $url;
  return $ua->get($url)->res->json;
}

1;
