package Orchestrate::Collection::Result;
use Mojo::Base -base;

use Carp 'croak';
use Orchestrate::Collection::Relationship;
use Data::Dumper;

has [qw(orchestrate collection data key ref etag column_names)];

sub get_related {
  return Orchestrate::Collection::Relationship->new(shift)->get_related;
}
sub columns {
  return @{shift->column_names};
}

1;

