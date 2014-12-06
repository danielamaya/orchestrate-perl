package Orchestrate::Collection::ResultSet;
use Mojo::Base -base;

use Carp 'croak';
use Data::Dumper;

has [qw(collection name)];

