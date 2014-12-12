package Orchestrate::Collection::Result;
use Mojo::Base -base;

use Carp 'croak';
use Orchestrate::Collection::Relationship;
use Data::Dumper;

has [qw(orchestrate collection data key ref etag column_names)];

sub get_related {
  return Orchestrate::Collection::Relationship->new(
    orchestrate => $_[0]->orchestrate,
    name => $_[0]->collection->name,
    key => $_[0]->key,
    kinds => $_[1]
  )->get_related;
}
sub columns {
  return @{shift->column_names};
}

1;

