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
  return Orchestrate::Collection->new(
    orchestrate => $self,
    name => $name,
    url => $self->secret_url->clone->path($name.'/')
  );

}

sub create_collection {
  my ($self, $key) = @_;
  my $orchestrate = $self->orchestrate;

  my $ua  = $orchestrate->ua;
  my $url = $self->url->clone->path($key);

  my $tx = $ua->put($url => { 'Content-Type' => 'application/json' });

  print $tx->res->code;

}

sub delete_collection {
  my ($self,$name) = shift;
  my $orchestrate = $self->orchestrate;

  my $ua = $orchestrate->ua;
  my $url = Mojo::URL->new($orchestrate->base_url)->userinfo($orchestrate->secret);

  $url->path($self->name);
  $url->query(force => 'true');

  return $ua->delete($url);

}


sub _build {
  my ($self, %args) = @_;
  croak qq{Your API key is required.} unless $args{secret};

  $self->secret($args{secret});
  $self->base_url($args{url}) if $args{url};
  $self->secret_url(Mojo::URL->new($self->base_url)->userinfo($self->secret));
  $self->_authenticate;

  return $self;
}

sub _authenticate {
  my $self = shift;

  my $ua  = $self->ua;
  my $url = $self->secret_url;
  my $tx  = $ua->head($url);

  croak qq{Authentication failed.} unless $tx->res->is_status_class(200);
}

sub _error {
  my $code = shift;

  my %codes = (
    api_bad_request   => 'The API request is malformed.',
    search_param_invalid  => 'A provided search query param is invalid.',
    search_query_malformed  => 'The provided search query is not a valid lucene query.',
    item_ref_malformed  => 'The provided Item Ref is malformed.',
    security_unauthorized  => 'Valid credentials are required.',
    items_not_found   => 'The requested items could not be found.',
    indexing_conflict   => 'The item has been stored but conflicts were detected when indexing. Conflicting fields have not been indexed.',
    item_version_mismatch =>  'The version of the item does not match.',
    item_already_present  => 'The item is already present.',
    security_authentication =>  'An error occurred while trying to authenticate.',
    search_index_not_found => 'Index could not be queried for this application.',
    internal_error => 'Internal Error.'
  );

  $codes{$code} ? return $codes{$code} : return;
}

1;

=encoding utf8

=head1 NAME

Orchestrate - Pure Perl, non-blocking, Orchestrate.io client.

=head1 SYNOPSIS

  use Orchestrate;

  # Create an orchestrate object
  my $orchestrate = Orchestrate->new(
    secret   => 'api-key',
    base_url => 'https://api.aws-us-east-1.orchestrate.io/v0/'
  )

  $orchestrate->create_collection('name');
  $orchestrate->delete_collection('name');

  # Return an Orchestrate::Collection object to interface with users collection
  my $users = $orchestrate->collection('users');

  # Find all keys starting with g in users collection
  # Returns an Orchestrate::Collection::Resultset Object
  my $rs = $users->search('g');

  # For each iteration of the loop, $data is an
  # Orchestrate::Collection::Result object to that result
  while (my $data = $rs->next) {
    say $rs->key;
    say $rs->ref;
    say Dumper $rs->data;

    $rs->update(data => { foo => 'bar', boo => ['baz', 'biz'] });
  }

=head1 DESCRIPTION

L<Orchestrate> is a Perl client to the Orchestrate API. See L<https://orchestrate.io/docs/apiref>
for Orchestrate's API documentation.

=head1 METHODS

=head2 new

Create a new orchestrate object. This will authenticate to Orchestrate.io API and die on failure.

Accepts the following parameters:

=over

=item secret => $api_key

The Orchestrate.io API key to use for requests. This parameter is required.

=item base_url => $url

The base_url to use for requests.

=head2 create_collection($name)

Creates a new collection on Orchestrate.

=head2 delete_collection($name)

Deletes an entire collection and all contents.

=head2 collection($name)

Returns an L<Orchestrate::Collection> object.

=head1 SEE ALSO

L<http://orchestrate.io>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 AUTHOR

Daniel Amaya, C<damaya@cpan.org>

=head1 COPYLEFT AND LICENSE

Copyleft (C) 2014, Nobody.

This program is free software, you can redistribute it and/or modify it under
the terms of the GNU GPLv3.

=cut