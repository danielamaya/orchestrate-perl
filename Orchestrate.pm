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
