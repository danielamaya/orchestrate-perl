package Orchestrate::Collection::Relationship;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(relationship)];

sub get_related {
  my $self = shift;

  print Dumper $self;
}

1;
