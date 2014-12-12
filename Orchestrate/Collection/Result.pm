package Orchestrate::Collection::Result;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(orchestrate collection name data)];


sub new {
  shift->SUPER::new->_build_rs(@_);
}

sub _build_rs {
  my ($self, $orchestrate, $collection, $data) = @_;


}

